-- ============================================================
-- EnterpriseRetailAI · Store Edge PostgreSQL Schema DDL
-- File: 06_DB_Schemas/store_edge_pg_DDL.sql
-- Database: PostgreSQL 16 (on-premises store edge node)
-- Purpose: Store-level canonical database — synced to cloud on reconnection
-- Schema: store_{store_id} (one schema per store on the edge node)
-- HA: Patroni active/standby on Tier A stores; single instance on Tier B
-- ============================================================

-- ============================================================
-- SECTION 1: TRANSACTIONS (store-level ledger)
-- ============================================================

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id       UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id            UUID         NOT NULL,
    store_id             UUID         NOT NULL,
    pos_id               UUID         NOT NULL,
    cashier_id           UUID         NOT NULL,
    shift_id             UUID         NOT NULL,
    idempotency_key      UUID         NOT NULL UNIQUE,
    state                VARCHAR(20)  NOT NULL
        CHECK (state IN ('COMPLETE','VOIDED','SUSPENDED','REFUNDED')),
    opened_at            TIMESTAMPTZ  NOT NULL,
    completed_at         TIMESTAMPTZ,
    voided_at            TIMESTAMPTZ,
    void_reason          TEXT,
    customer_id          UUID,
    loyalty_id           VARCHAR(50),
    currency             CHAR(3)      NOT NULL DEFAULT 'GBP',
    subtotal_minor       BIGINT       NOT NULL DEFAULT 0,
    tax_total_minor      BIGINT       NOT NULL DEFAULT 0,
    discount_total_minor BIGINT       NOT NULL DEFAULT 0,
    grand_total_minor    BIGINT       NOT NULL DEFAULT 0,
    line_count           SMALLINT     NOT NULL DEFAULT 0,
    quantity_total       INTEGER      NOT NULL DEFAULT 0,
    payment_method       VARCHAR(30),
    is_offline_tx        BOOLEAN      NOT NULL DEFAULT false,
    receipt_number       VARCHAR(50),
    fraud_score          NUMERIC(5,4),
    fraud_decision       VARCHAR(10),
    vector_clock         JSONB,
    cloud_synced         BOOLEAN      NOT NULL DEFAULT false,
    cloud_synced_at      TIMESTAMPTZ,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_store_transactions PRIMARY KEY (transaction_id)
);

CREATE INDEX idx_store_tx_pos_date
    ON transactions (pos_id, completed_at DESC);
CREATE INDEX idx_store_tx_unsynced
    ON transactions (created_at)
    WHERE cloud_synced = false;
CREATE INDEX idx_store_tx_customer
    ON transactions (customer_id)
    WHERE customer_id IS NOT NULL;

-- ============================================================

CREATE TABLE IF NOT EXISTS transaction_lines (
    line_id              UUID         NOT NULL DEFAULT gen_random_uuid(),
    transaction_id       UUID         NOT NULL
                             REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    sku_id               UUID         NOT NULL,
    barcode              VARCHAR(50),
    product_name         VARCHAR(255) NOT NULL,
    category             VARCHAR(100),
    quantity             INTEGER      NOT NULL,
    unit_price_minor     BIGINT       NOT NULL,
    tax_rate_pct         NUMERIC(6,4) NOT NULL DEFAULT 0,
    tax_amount_minor     BIGINT       NOT NULL DEFAULT 0,
    discount_amount_minor BIGINT      NOT NULL DEFAULT 0,
    line_total_minor     BIGINT       NOT NULL,
    is_return_line       BOOLEAN      NOT NULL DEFAULT false,
    original_line_id     UUID,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_store_lines PRIMARY KEY (line_id)
);

CREATE INDEX idx_store_lines_tx ON transaction_lines (transaction_id);
CREATE INDEX idx_store_lines_sku ON transaction_lines (sku_id);

-- ============================================================
-- SECTION 2: INVENTORY (store-level real-time stock)
-- ============================================================

CREATE TABLE IF NOT EXISTS inventory (
    inventory_id         UUID         NOT NULL DEFAULT gen_random_uuid(),
    store_id             UUID         NOT NULL,
    sku_id               UUID         NOT NULL,
    sku_name             VARCHAR(255),
    barcode              VARCHAR(50),
    category             VARCHAR(100),
    quantity_on_hand     INTEGER      NOT NULL DEFAULT 0,
    quantity_reserved    INTEGER      NOT NULL DEFAULT 0,
    quantity_in_transit  INTEGER      NOT NULL DEFAULT 0,
    reorder_point        INTEGER,
    reorder_qty          INTEGER,
    last_count_at        TIMESTAMPTZ,
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    version              BIGINT       NOT NULL DEFAULT 1,   -- optimistic locking
    CONSTRAINT pk_store_inventory PRIMARY KEY (inventory_id),
    CONSTRAINT uq_store_sku UNIQUE (store_id, sku_id)
);

CREATE INDEX idx_store_inv_sku ON inventory (store_id, sku_id);
CREATE INDEX idx_store_inv_low
    ON inventory (store_id)
    WHERE quantity_on_hand <= reorder_point;

CREATE TABLE IF NOT EXISTS inventory_movements (
    movement_id          UUID         NOT NULL DEFAULT gen_random_uuid(),
    store_id             UUID         NOT NULL,
    sku_id               UUID         NOT NULL,
    movement_type        VARCHAR(20)  NOT NULL
        CHECK (movement_type IN ('SALE','RETURN','RECEIPT','ADJUSTMENT',
                                  'TRANSFER_IN','TRANSFER_OUT','SHRINKAGE','COUNT')),
    quantity_delta       INTEGER      NOT NULL,
    reference_id         UUID,        -- transaction_id or PO id
    reference_type       VARCHAR(30),
    performed_by         UUID,
    notes                TEXT,
    idempotency_key      UUID         UNIQUE,
    cloud_synced         BOOLEAN      NOT NULL DEFAULT false,
    movement_at          TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_store_movements PRIMARY KEY (movement_id)
);

CREATE INDEX idx_store_movements_sku
    ON inventory_movements (store_id, sku_id, movement_at DESC);
CREATE INDEX idx_store_movements_unsynced
    ON inventory_movements (movement_at)
    WHERE cloud_synced = false;

-- ============================================================
-- SECTION 3: LOYALTY (store-level balance cache)
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty_balances (
    account_id           UUID         NOT NULL,
    customer_id          UUID,
    loyalty_number       VARCHAR(50)  NOT NULL,
    points_balance       BIGINT       NOT NULL DEFAULT 0,
    tier                 VARCHAR(20)  NOT NULL DEFAULT 'STANDARD',
    last_cloud_sync      TIMESTAMPTZ,
    is_stale             BOOLEAN      NOT NULL DEFAULT false,
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_store_loyalty PRIMARY KEY (account_id)
);

CREATE INDEX idx_store_loyalty_number ON loyalty_balances (loyalty_number);

CREATE TABLE IF NOT EXISTS loyalty_transactions (
    lt_id                UUID         NOT NULL DEFAULT gen_random_uuid(),
    account_id           UUID         NOT NULL,
    transaction_id       UUID,
    movement_type        VARCHAR(10)  NOT NULL CHECK (movement_type IN ('EARN','BURN','EXPIRE','ADJUST')),
    points_delta         BIGINT       NOT NULL,
    points_balance_after BIGINT       NOT NULL,
    idempotency_key      UUID         UNIQUE,
    cloud_synced         BOOLEAN      NOT NULL DEFAULT false,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_store_loyalty_tx PRIMARY KEY (lt_id)
);

CREATE INDEX idx_store_loyalty_tx_account
    ON loyalty_transactions (account_id, created_at DESC);
CREATE INDEX idx_store_loyalty_tx_unsynced
    ON loyalty_transactions (created_at)
    WHERE cloud_synced = false;

-- ============================================================
-- SECTION 4: OFFLINE PAYMENT TOKENS (pending settlement)
-- ============================================================

CREATE TABLE IF NOT EXISTS offline_payment_tokens (
    token_id             UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id            UUID         NOT NULL,
    pos_id               UUID         NOT NULL,
    shift_id             UUID         NOT NULL,
    token_hmac           BYTEA        NOT NULL,     -- HMAC-SHA256
    amount_minor         BIGINT       NOT NULL,
    currency             CHAR(3)      NOT NULL,
    card_type            VARCHAR(20)  NOT NULL,
    masked_pan           VARCHAR(30),               -- masked reference only
    expiry_at            TIMESTAMPTZ  NOT NULL,
    status               VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','SETTLED','EXPIRED','FAILED','TAMPERED')),
    retry_count          SMALLINT     NOT NULL DEFAULT 0,
    settlement_ref       VARCHAR(100),
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    settled_at           TIMESTAMPTZ,
    CONSTRAINT pk_edge_offline_tokens PRIMARY KEY (token_id)
);

CREATE INDEX idx_edge_tokens_pending
    ON offline_payment_tokens (created_at)
    WHERE status = 'PENDING';
CREATE INDEX idx_edge_tokens_expiry
    ON offline_payment_tokens (expiry_at)
    WHERE status = 'PENDING';

-- ============================================================
-- SECTION 5: SYNC STATE (per-POS vector clock tracking)
-- ============================================================

CREATE TABLE IF NOT EXISTS sync_state (
    device_id            VARCHAR(100) NOT NULL,     -- POS-STORE001-T01
    device_type          VARCHAR(20)  NOT NULL DEFAULT 'POS',
    last_vector_clock    JSONB        NOT NULL DEFAULT '{}',
    last_event_id        UUID,
    last_sync_at         TIMESTAMPTZ,
    last_ack_at          TIMESTAMPTZ,
    events_pending       INTEGER      NOT NULL DEFAULT 0,
    is_online            BOOLEAN      NOT NULL DEFAULT false,
    offline_since        TIMESTAMPTZ,
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_sync_state PRIMARY KEY (device_id)
);

-- ============================================================
-- SECTION 6: SHIFTS (store-level aggregated records)
-- ============================================================

CREATE TABLE IF NOT EXISTS shifts (
    shift_id             UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id            UUID         NOT NULL,
    store_id             UUID         NOT NULL,
    pos_id               UUID         NOT NULL,
    cashier_id           UUID         NOT NULL,
    cashier_name         VARCHAR(100),
    opened_at            TIMESTAMPTZ  NOT NULL,
    closed_at            TIMESTAMPTZ,
    opening_float_minor  BIGINT       NOT NULL DEFAULT 0,
    closing_float_minor  BIGINT,
    cash_variance_minor  BIGINT,
    tx_count             INTEGER      NOT NULL DEFAULT 0,
    gross_sales_minor    BIGINT       NOT NULL DEFAULT 0,
    discount_total_minor BIGINT       NOT NULL DEFAULT 0,
    tax_collected_minor  BIGINT       NOT NULL DEFAULT 0,
    void_count           SMALLINT     NOT NULL DEFAULT 0,
    return_count         SMALLINT     NOT NULL DEFAULT 0,
    offline_period_minutes INTEGER    NOT NULL DEFAULT 0,
    status               VARCHAR(20)  NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN','CLOSED','RECONCILED')),
    cloud_synced         BOOLEAN      NOT NULL DEFAULT false,
    CONSTRAINT pk_store_shifts PRIMARY KEY (shift_id)
);

CREATE INDEX idx_store_shifts_pos ON shifts (pos_id, opened_at DESC);
CREATE INDEX idx_store_shifts_open ON shifts (store_id) WHERE status = 'OPEN';

-- ============================================================
-- SECTION 7: AI INFERENCE LOG (edge model outputs)
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_inference_log (
    inference_id         UUID         NOT NULL DEFAULT gen_random_uuid(),
    store_id             UUID         NOT NULL,
    device_id            VARCHAR(100) NOT NULL,
    model_name           VARCHAR(50)  NOT NULL,
    model_version        VARCHAR(20)  NOT NULL,
    entity_type          VARCHAR(30)  NOT NULL,  -- transaction | customer | device | item
    entity_id            UUID,
    prediction_type      VARCHAR(30)  NOT NULL,  -- fraud_score | promo_rank | cv_detection
    score                NUMERIC(8,6),
    decision             VARCHAR(20),
    inference_ms         INTEGER,
    predicted_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    cloud_synced         BOOLEAN      NOT NULL DEFAULT false,
    CONSTRAINT pk_ai_inference_log PRIMARY KEY (inference_id)
);

CREATE INDEX idx_ai_log_device ON ai_inference_log (device_id, predicted_at DESC);
CREATE INDEX idx_ai_log_unsynced ON ai_inference_log (predicted_at)
    WHERE cloud_synced = false;

-- ============================================================
-- SECTION 8: STORE CONFIGURATION (local config cache)
-- ============================================================

CREATE TABLE IF NOT EXISTS store_config (
    config_key           VARCHAR(100) NOT NULL PRIMARY KEY,
    config_value         TEXT         NOT NULL,
    config_type          VARCHAR(20)  NOT NULL DEFAULT 'STRING'
        CHECK (config_type IN ('STRING','INTEGER','BOOLEAN','JSON')),
    description          TEXT,
    last_pushed_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    version              INTEGER      NOT NULL DEFAULT 1
);

-- Seed essential config values at store provisioning:
INSERT INTO store_config (config_key, config_value, config_type, description)
VALUES
    ('store.offline_payment_ceiling_minor', '50000', 'INTEGER', 'Max offline payment per transaction (minor units)'),
    ('store.loyalty_points_per_unit',       '1',     'INTEGER', 'Points earned per currency unit spent'),
    ('store.sync_batch_size',               '100',   'INTEGER', 'Events per sync batch to cloud'),
    ('store.fraud_score_allow_threshold',   '0.40',  'STRING',  'Fraud score below which to allow'),
    ('store.fraud_score_decline_threshold', '0.70',  'STRING',  'Fraud score above which to decline'),
    ('store.offline_timeout_seconds',       '30',    'INTEGER', 'Seconds before switching to offline mode'),
    ('store.max_promo_discount_pct',        '40',    'INTEGER', 'Maximum cumulative promo discount %'),
    ('store.receipt_header',                '',      'STRING',  'Custom receipt header text')
ON CONFLICT (config_key) DO NOTHING;

-- ============================================================
-- SECTION 9: PRODUCT CACHE (store-level SKU list)
-- ============================================================

CREATE TABLE IF NOT EXISTS product_cache (
    sku_id               UUID         NOT NULL PRIMARY KEY,
    barcode              VARCHAR(50)  NOT NULL UNIQUE,
    name                 VARCHAR(255) NOT NULL,
    category             VARCHAR(100) NOT NULL,
    subcategory          VARCHAR(100),
    brand                VARCHAR(100),
    base_price_minor     BIGINT       NOT NULL,
    tax_category         VARCHAR(30)  NOT NULL DEFAULT 'standard',
    weight_grams         NUMERIC(10,3),
    is_age_restricted    BOOLEAN      NOT NULL DEFAULT false,
    is_weighable         BOOLEAN      NOT NULL DEFAULT false,
    is_active            BOOLEAN      NOT NULL DEFAULT true,
    image_url            TEXT,
    catalogue_version    VARCHAR(50)  NOT NULL,
    cached_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_store_product_barcode ON product_cache (barcode);
CREATE INDEX idx_store_product_category ON product_cache (category);

-- Full-text search
CREATE INDEX idx_store_product_fts
    ON product_cache
    USING gin(to_tsvector('english', coalesce(name,'') || ' ' || coalesce(brand,'')));

-- ============================================================
-- SECTION 10: PROMOTION RULES (store-level active promotions)
-- ============================================================

CREATE TABLE IF NOT EXISTS promotion_rules (
    promo_id             UUID         NOT NULL PRIMARY KEY,
    name                 VARCHAR(255) NOT NULL,
    discount_type        VARCHAR(20)  NOT NULL,
    discount_value       NUMERIC(10,4) NOT NULL,
    min_basket_minor     BIGINT       DEFAULT 0,
    max_discount_minor   BIGINT,
    applicable_skus      UUID[],
    applicable_categories VARCHAR(100)[],
    exclusive_group      VARCHAR(50),
    requires_loyalty     BOOLEAN      NOT NULL DEFAULT false,
    valid_from           TIMESTAMPTZ  NOT NULL,
    valid_until          TIMESTAMPTZ  NOT NULL,
    customer_reason      VARCHAR(255),
    is_active            BOOLEAN      NOT NULL DEFAULT true,
    promo_version        INTEGER      NOT NULL DEFAULT 1,
    synced_at            TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_store_promo_active
    ON promotion_rules (valid_from, valid_until)
    WHERE is_active = true;

-- ============================================================
-- SECTION 11: EVENT QUEUE (Kafka-backed — metadata table)
-- ============================================================

CREATE TABLE IF NOT EXISTS event_queue_state (
    topic                VARCHAR(100) NOT NULL,
    partition_id         INTEGER      NOT NULL,
    last_offset          BIGINT       NOT NULL DEFAULT 0,
    last_event_id        UUID,
    consumer_group       VARCHAR(100) NOT NULL DEFAULT 'store-sync-manager',
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_event_queue_state PRIMARY KEY (topic, partition_id, consumer_group)
);

-- ============================================================
-- END OF STORE EDGE POSTGRESQL SCHEMA DDL
-- ============================================================
