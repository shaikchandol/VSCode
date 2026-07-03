-- ============================================================
-- EnterpriseRetailAI · Tenant Schema DDL
-- File: 06_DB_Schemas/tenant_schema_DDL.sql
-- Database: PostgreSQL 16 (Azure SQL Flexible)
-- Purpose: Full DDL for a single franchisee tenant schema
-- Usage: Run once per tenant during provisioning (LLD-010)
--        Schema name substituted by Terraform: :schema_name
-- ============================================================

-- ============================================================
-- SECTION 1: TRANSACTIONS
-- ============================================================

CREATE TABLE :schema_name.transactions (
    transaction_id         UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id              UUID         NOT NULL,
    store_id               UUID         NOT NULL,
    pos_id                 UUID         NOT NULL,
    cashier_id             UUID         NOT NULL,
    shift_id               UUID         NOT NULL,
    idempotency_key        UUID         NOT NULL,
    state                  VARCHAR(20)  NOT NULL
                               CHECK (state IN ('COMPLETE','VOIDED','SUSPENDED','REFUNDED')),
    opened_at              TIMESTAMPTZ  NOT NULL,
    completed_at           TIMESTAMPTZ,
    voided_at              TIMESTAMPTZ,
    void_reason            TEXT,
    void_authorised_by     UUID,
    customer_id            UUID,
    loyalty_id             VARCHAR(50),
    currency               CHAR(3)      NOT NULL DEFAULT 'GBP',
    subtotal_minor         BIGINT       NOT NULL DEFAULT 0,
    tax_total_minor        BIGINT       NOT NULL DEFAULT 0,
    discount_total_minor   BIGINT       NOT NULL DEFAULT 0,
    grand_total_minor      BIGINT       NOT NULL DEFAULT 0,
    line_count             SMALLINT     NOT NULL DEFAULT 0,
    quantity_total         INTEGER      NOT NULL DEFAULT 0,
    payment_method         VARCHAR(30),
    is_offline_tx          BOOLEAN      NOT NULL DEFAULT false,
    receipt_number         VARCHAR(50),
    fraud_score            NUMERIC(5,4),
    fraud_decision         VARCHAR(10),
    notes                  TEXT,
    vector_clock           JSONB,
    created_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_transactions PRIMARY KEY (transaction_id),
    CONSTRAINT uq_transactions_idempotency UNIQUE (idempotency_key),
    CONSTRAINT chk_transactions_totals CHECK (grand_total_minor >= 0)
);

CREATE INDEX idx_transactions_store_date
    ON :schema_name.transactions (store_id, completed_at DESC)
    WHERE state = 'COMPLETE';
CREATE INDEX idx_transactions_cashier
    ON :schema_name.transactions (cashier_id, opened_at DESC);
CREATE INDEX idx_transactions_customer
    ON :schema_name.transactions (customer_id)
    WHERE customer_id IS NOT NULL;
CREATE INDEX idx_transactions_offline
    ON :schema_name.transactions (completed_at DESC)
    WHERE is_offline_tx = true;

ALTER TABLE :schema_name.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_transactions ON :schema_name.transactions
    USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- ============================================================

CREATE TABLE :schema_name.transaction_lines (
    line_id                UUID         NOT NULL DEFAULT gen_random_uuid(),
    transaction_id         UUID         NOT NULL
                               REFERENCES :schema_name.transactions(transaction_id) ON DELETE CASCADE,
    tenant_id              UUID         NOT NULL,
    sku_id                 UUID         NOT NULL,
    barcode                VARCHAR(50),
    product_name           VARCHAR(255) NOT NULL,
    category               VARCHAR(100),
    subcategory            VARCHAR(100),
    quantity               INTEGER      NOT NULL CHECK (quantity != 0),  -- negative for returns
    unit_price_minor       BIGINT       NOT NULL CHECK (unit_price_minor >= 0),
    tax_rate_pct           NUMERIC(6,4) NOT NULL DEFAULT 0,
    tax_amount_minor       BIGINT       NOT NULL DEFAULT 0,
    discount_amount_minor  BIGINT       NOT NULL DEFAULT 0,
    line_total_minor       BIGINT       NOT NULL,
    is_return_line         BOOLEAN      NOT NULL DEFAULT false,
    original_line_id       UUID,
    created_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_transaction_lines PRIMARY KEY (line_id)
);

CREATE INDEX idx_tx_lines_transaction ON :schema_name.transaction_lines (transaction_id);
CREATE INDEX idx_tx_lines_sku ON :schema_name.transaction_lines (sku_id, created_at DESC);

ALTER TABLE :schema_name.transaction_lines ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_tx_lines ON :schema_name.transaction_lines
    USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- ============================================================
-- SECTION 2: CUSTOMERS (PII — GDPR/DPDP Scope)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE :schema_name.customers (
    customer_id            UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id              UUID         NOT NULL,
    loyalty_number         VARCHAR(50),
    email_hash             BYTEA,
    email_encrypted        BYTEA,       -- pgp_sym_encrypt(email, cmk)
    first_name_encrypted   BYTEA,
    last_name_encrypted    BYTEA,
    phone_encrypted        BYTEA,
    date_of_birth          DATE,
    country_code           CHAR(2)      NOT NULL,
    preferred_language     CHAR(5)      DEFAULT 'en-GB',
    is_erased              BOOLEAN      NOT NULL DEFAULT false,
    consent_marketing      BOOLEAN      NOT NULL DEFAULT false,
    consent_personalised   BOOLEAN      NOT NULL DEFAULT false,
    consent_data_sharing   BOOLEAN      NOT NULL DEFAULT false,
    consent_updated_at     TIMESTAMPTZ,
    segment_code           VARCHAR(20),
    rfm_score              NUMERIC(4,2),
    lifetime_points        BIGINT       NOT NULL DEFAULT 0,
    created_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at             TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_customers PRIMARY KEY (customer_id),
    CONSTRAINT uq_customers_loyalty UNIQUE (loyalty_number)
);

CREATE INDEX idx_customers_loyalty ON :schema_name.customers (loyalty_number)
    WHERE loyalty_number IS NOT NULL AND NOT is_erased;
CREATE INDEX idx_customers_email_hash ON :schema_name.customers (email_hash)
    WHERE email_hash IS NOT NULL AND NOT is_erased;
CREATE INDEX idx_customers_segment ON :schema_name.customers (segment_code)
    WHERE NOT is_erased;

ALTER TABLE :schema_name.customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_customers ON :schema_name.customers
    USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Customer consent history (immutable log)
CREATE TABLE :schema_name.customer_consent_log (
    log_id            UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id         UUID         NOT NULL,
    customer_id       UUID         NOT NULL
                          REFERENCES :schema_name.customers(customer_id),
    purpose           VARCHAR(50)  NOT NULL,
    action            VARCHAR(10)  NOT NULL CHECK (action IN ('GRANT','WITHDRAW')),
    channel           VARCHAR(20)  NOT NULL,  -- POS | WEB | APP | STAFF
    ip_address        INET,
    consented_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_consent_log PRIMARY KEY (log_id)
);

-- ============================================================
-- SECTION 3: INVENTORY
-- ============================================================

CREATE TABLE :schema_name.inventory (
    inventory_id       UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    store_id           UUID         NOT NULL,
    sku_id             UUID         NOT NULL,
    quantity_on_hand   INTEGER      NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved  INTEGER      NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    quantity_in_transit INTEGER     NOT NULL DEFAULT 0,
    reorder_point      INTEGER,
    reorder_qty        INTEGER,
    last_count_at      TIMESTAMPTZ,
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    version            BIGINT       NOT NULL DEFAULT 1,
    CONSTRAINT pk_inventory PRIMARY KEY (inventory_id),
    CONSTRAINT uq_inventory_store_sku UNIQUE (store_id, sku_id)
);

CREATE INDEX idx_inventory_store ON :schema_name.inventory (store_id, sku_id);
CREATE INDEX idx_inventory_low_stock ON :schema_name.inventory (store_id, quantity_on_hand)
    WHERE quantity_on_hand <= reorder_point;

ALTER TABLE :schema_name.inventory ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_inventory ON :schema_name.inventory
    USING (tenant_id = current_setting('app.tenant_id')::uuid);

CREATE TABLE :schema_name.inventory_movements (
    movement_id     UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       UUID         NOT NULL,
    store_id        UUID         NOT NULL,
    sku_id          UUID         NOT NULL,
    movement_type   VARCHAR(20)  NOT NULL
        CHECK (movement_type IN ('SALE','RETURN','RECEIPT','ADJUSTMENT',
                                  'TRANSFER_IN','TRANSFER_OUT','SHRINKAGE','COUNT')),
    quantity_delta  INTEGER      NOT NULL,
    reference_id    UUID,
    reference_type  VARCHAR(30),
    performed_by    UUID,
    notes           TEXT,
    idempotency_key UUID         UNIQUE,
    movement_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_inventory_movements PRIMARY KEY (movement_id)
);

CREATE INDEX idx_inv_movements_store_sku
    ON :schema_name.inventory_movements (store_id, sku_id, movement_at DESC);

-- ============================================================
-- SECTION 4: LOYALTY
-- ============================================================

CREATE TABLE :schema_name.loyalty_accounts (
    account_id       UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id        UUID         NOT NULL,
    customer_id      UUID         NOT NULL
                         REFERENCES :schema_name.customers(customer_id),
    loyalty_number   VARCHAR(50)  NOT NULL UNIQUE,
    points_balance   BIGINT       NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
    tier             VARCHAR(20)  NOT NULL DEFAULT 'STANDARD'
        CHECK (tier IN ('STANDARD','SILVER','GOLD','PLATINUM')),
    tier_qualified_at TIMESTAMPTZ,
    tier_expiry_at   TIMESTAMPTZ,
    lifetime_points  BIGINT       NOT NULL DEFAULT 0,
    is_active        BOOLEAN      NOT NULL DEFAULT true,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_loyalty_accounts PRIMARY KEY (account_id)
);

CREATE INDEX idx_loyalty_customer ON :schema_name.loyalty_accounts (customer_id);
CREATE INDEX idx_loyalty_number ON :schema_name.loyalty_accounts (loyalty_number)
    WHERE is_active = true;

CREATE TABLE :schema_name.loyalty_transactions (
    lt_id             UUID        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id         UUID        NOT NULL,
    account_id        UUID        NOT NULL
                          REFERENCES :schema_name.loyalty_accounts(account_id),
    transaction_id    UUID,
    movement_type     VARCHAR(10) NOT NULL CHECK (movement_type IN ('EARN','BURN','EXPIRE','ADJUST')),
    points_delta      BIGINT      NOT NULL,
    points_balance_after BIGINT   NOT NULL,
    expiry_date       DATE,
    is_offline_accrual BOOLEAN    NOT NULL DEFAULT false,
    idempotency_key   UUID        UNIQUE,
    notes             TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_loyalty_transactions PRIMARY KEY (lt_id)
);

CREATE INDEX idx_loyalty_tx_account
    ON :schema_name.loyalty_transactions (account_id, created_at DESC);

-- ============================================================
-- SECTION 5: PAYMENTS (PCI-DSS CDE)
-- ============================================================

CREATE TABLE :schema_name.payment_records (
    payment_id        UUID        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id         UUID        NOT NULL,
    transaction_id    UUID        NOT NULL,
    payment_method    VARCHAR(20) NOT NULL
        CHECK (payment_method IN ('EMV_CHIP','CONTACTLESS_NFC','CONTACTLESS_DEVICE',
                                   'QR_CODE','CASH','GIFT_CARD','OFFLINE_TOKEN','SPLIT')),
    amount_minor      BIGINT      NOT NULL CHECK (amount_minor > 0),
    currency          CHAR(3)     NOT NULL,
    token_reference   VARCHAR(255),       -- gateway PSP reference (no PAN)
    auth_code         VARCHAR(20),
    gateway_ref       VARCHAR(100),
    is_offline        BOOLEAN     NOT NULL DEFAULT false,
    offline_token_id  UUID,
    status            VARCHAR(25) NOT NULL DEFAULT 'APPROVED'
        CHECK (status IN ('APPROVED','DECLINED','PENDING_SETTLEMENT',
                           'SETTLED','REFUNDED','DISPUTED','EXPIRED')),
    processed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    settled_at        TIMESTAMPTZ,
    CONSTRAINT pk_payment_records PRIMARY KEY (payment_id)
);

CREATE INDEX idx_payment_transaction ON :schema_name.payment_records (transaction_id);
CREATE INDEX idx_payment_status ON :schema_name.payment_records (status, processed_at DESC)
    WHERE status IN ('PENDING_SETTLEMENT','DISPUTED');

CREATE TABLE :schema_name.offline_payment_tokens (
    token_id          UUID        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id         UUID        NOT NULL,
    pos_id            UUID        NOT NULL,
    shift_id          UUID        NOT NULL,
    token_hmac        BYTEA       NOT NULL,     -- HMAC-SHA256 signed token
    amount_minor      BIGINT      NOT NULL,
    currency          CHAR(3)     NOT NULL,
    card_type         VARCHAR(20) NOT NULL,
    expiry_at         TIMESTAMPTZ NOT NULL,
    status            VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','SETTLED','EXPIRED','FAILED','TAMPERED')),
    retry_count       SMALLINT    NOT NULL DEFAULT 0,
    settlement_ref    VARCHAR(100),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    settled_at        TIMESTAMPTZ,
    CONSTRAINT pk_offline_tokens PRIMARY KEY (token_id)
);

CREATE INDEX idx_offline_tokens_pending
    ON :schema_name.offline_payment_tokens (created_at)
    WHERE status = 'PENDING';

-- ============================================================
-- SECTION 6: SHIFTS
-- ============================================================

CREATE TABLE :schema_name.shifts (
    shift_id              UUID        NOT NULL DEFAULT gen_random_uuid(),
    tenant_id             UUID        NOT NULL,
    store_id              UUID        NOT NULL,
    pos_id                UUID        NOT NULL,
    cashier_id            UUID        NOT NULL,
    opened_at             TIMESTAMPTZ NOT NULL,
    closed_at             TIMESTAMPTZ,
    opening_float_minor   BIGINT      NOT NULL DEFAULT 0,
    closing_float_minor   BIGINT,
    cash_variance_minor   BIGINT,
    tx_count              INTEGER     NOT NULL DEFAULT 0,
    gross_sales_minor     BIGINT      NOT NULL DEFAULT 0,
    discount_total_minor  BIGINT      NOT NULL DEFAULT 0,
    tax_collected_minor   BIGINT      NOT NULL DEFAULT 0,
    void_count            SMALLINT    NOT NULL DEFAULT 0,
    return_count          SMALLINT    NOT NULL DEFAULT 0,
    offline_period_minutes INTEGER    NOT NULL DEFAULT 0,
    status                VARCHAR(20) NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN','CLOSED','RECONCILED')),
    CONSTRAINT pk_shifts PRIMARY KEY (shift_id)
);

CREATE INDEX idx_shifts_store_date ON :schema_name.shifts (store_id, opened_at DESC);
CREATE INDEX idx_shifts_cashier ON :schema_name.shifts (cashier_id, opened_at DESC);

-- ============================================================
-- SECTION 7: PRODUCTS (Tenant Overrides)
-- ============================================================

CREATE TABLE :schema_name.product_overrides (
    override_id        UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    sku_id             UUID         NOT NULL,
    local_name         VARCHAR(255),
    local_description  TEXT,
    price_override_minor BIGINT,
    is_active          BOOLEAN      NOT NULL DEFAULT true,
    store_id           UUID,                    -- NULL = all stores in tenant
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_product_overrides PRIMARY KEY (override_id),
    CONSTRAINT uq_product_override UNIQUE (tenant_id, sku_id, store_id)
);

-- ============================================================
-- SECTION 8: PROMOTIONS
-- ============================================================

CREATE TABLE :schema_name.promotions (
    promo_id           UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    name               VARCHAR(255) NOT NULL,
    description        TEXT,
    discount_type      VARCHAR(20)  NOT NULL
        CHECK (discount_type IN ('PCT','FIXED','BOGO','BUNDLE','FREE_ITEM')),
    discount_value     NUMERIC(10,4) NOT NULL,
    min_basket_minor   BIGINT       DEFAULT 0,
    max_discount_minor BIGINT,
    budget_minor       BIGINT,
    budget_used_minor  BIGINT       NOT NULL DEFAULT 0,
    applicable_skus    UUID[],
    applicable_categories VARCHAR(100)[],
    exclusive_group    VARCHAR(50),
    valid_from         TIMESTAMPTZ  NOT NULL,
    valid_until        TIMESTAMPTZ  NOT NULL,
    is_active          BOOLEAN      NOT NULL DEFAULT true,
    requires_loyalty   BOOLEAN      NOT NULL DEFAULT false,
    customer_reason    VARCHAR(255),
    promo_version      INTEGER      NOT NULL DEFAULT 1,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_promotions PRIMARY KEY (promo_id)
);

CREATE INDEX idx_promotions_active
    ON :schema_name.promotions (valid_from, valid_until)
    WHERE is_active = true;

CREATE TABLE :schema_name.applied_promotions (
    applied_id         UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    transaction_id     UUID         NOT NULL
                           REFERENCES :schema_name.transactions(transaction_id),
    promo_id           UUID         NOT NULL,
    discount_amount_minor BIGINT    NOT NULL,
    ai_score           NUMERIC(5,4),
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_applied_promotions PRIMARY KEY (applied_id)
);

-- ============================================================
-- SECTION 9: STAFF
-- ============================================================

CREATE TABLE :schema_name.staff (
    staff_id           UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    store_id           UUID,                   -- NULL = multi-store/admin
    aad_object_id      UUID         NOT NULL UNIQUE,
    display_name       VARCHAR(100) NOT NULL,
    email_encrypted    BYTEA,
    role               VARCHAR(30)  NOT NULL
        CHECK (role IN ('CASHIER','SUPERVISOR','STORE_MANAGER','FRANCHISEE_ADMIN')),
    is_active          BOOLEAN      NOT NULL DEFAULT true,
    pin_hash           BYTEA,                  -- PBKDF2-HMAC-SHA256
    pin_salt           BYTEA,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_staff PRIMARY KEY (staff_id)
);

CREATE INDEX idx_staff_store ON :schema_name.staff (store_id) WHERE is_active = true;
CREATE INDEX idx_staff_aad ON :schema_name.staff (aad_object_id);

-- ============================================================
-- SECTION 10: TAX RATES
-- ============================================================

CREATE TABLE :schema_name.tax_rates (
    rate_id            UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    jurisdiction       CHAR(3)      NOT NULL,  -- ISO 3166-1 alpha-3
    tax_category       VARCHAR(30)  NOT NULL,
    rate_pct           NUMERIC(6,4) NOT NULL,
    effective_from     DATE         NOT NULL,
    effective_until    DATE,
    CONSTRAINT pk_tax_rates PRIMARY KEY (rate_id),
    CONSTRAINT uq_tax_rates UNIQUE (jurisdiction, tax_category, effective_from)
);

-- ============================================================
-- SECTION 11: AUDIT LOG (Immutable — no UPDATE/DELETE grants)
-- ============================================================

CREATE TABLE :schema_name.audit_log (
    audit_id           UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    event_type         VARCHAR(100) NOT NULL,
    actor_id           UUID,
    actor_type         VARCHAR(20),
    resource_id        UUID,
    resource_type      VARCHAR(50),
    action             VARCHAR(50)  NOT NULL,
    outcome            VARCHAR(10)  NOT NULL CHECK (outcome IN ('SUCCESS','FAILURE')),
    ip_address         INET,
    pos_id             UUID,
    store_id           UUID,
    payload_hash       BYTEA,       -- SHA-256 of event payload
    event_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_audit_log PRIMARY KEY (audit_id)
);

-- audit_log: app DB user has INSERT only — no UPDATE/DELETE
CREATE INDEX idx_audit_event_at ON :schema_name.audit_log (event_at DESC);
CREATE INDEX idx_audit_actor    ON :schema_name.audit_log (actor_id, event_at DESC);
CREATE INDEX idx_audit_resource ON :schema_name.audit_log (resource_type, resource_id, event_at DESC);

-- ============================================================
-- SECTION 12: ML FEATURES & PREDICTIONS (AI Platform)
-- ============================================================

CREATE TABLE :schema_name.ml_predictions (
    prediction_id      UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    model_name         VARCHAR(50)  NOT NULL,
    model_version      VARCHAR(20)  NOT NULL,
    entity_type        VARCHAR(30)  NOT NULL,  -- transaction | customer | device | sku
    entity_id          UUID         NOT NULL,
    prediction_type    VARCHAR(30)  NOT NULL,
    score              NUMERIC(8,6),
    output_json        JSONB,
    feature_hash       BYTEA,       -- SHA-256 of feature vector for audit
    inference_ms       INTEGER,
    predicted_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_ml_predictions PRIMARY KEY (prediction_id)
);

CREATE INDEX idx_predictions_entity
    ON :schema_name.ml_predictions (entity_type, entity_id, predicted_at DESC);
CREATE INDEX idx_predictions_model
    ON :schema_name.ml_predictions (model_name, predicted_at DESC);

-- ============================================================
-- SECTION 13: SYNC STATE (Edge Coordination)
-- ============================================================

CREATE TABLE :schema_name.sync_state (
    sync_id            UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    store_id           UUID         NOT NULL,
    device_id          VARCHAR(100) NOT NULL,
    device_type        VARCHAR(20)  NOT NULL CHECK (device_type IN ('POS','STORE_EDGE')),
    vector_clock       JSONB        NOT NULL DEFAULT '{}',
    last_event_id      UUID,
    last_sync_at       TIMESTAMPTZ,
    offline_since      TIMESTAMPTZ,
    events_pending     INTEGER      NOT NULL DEFAULT 0,
    CONSTRAINT pk_sync_state PRIMARY KEY (sync_id),
    CONSTRAINT uq_sync_device UNIQUE (store_id, device_id)
);

-- ============================================================
-- SECTION 14: FORECASTS (Demand Planning)
-- ============================================================

CREATE TABLE :schema_name.demand_forecasts (
    forecast_id        UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL,
    store_id           UUID         NOT NULL,
    sku_id             UUID         NOT NULL,
    as_of_date         DATE         NOT NULL,
    horizon_7d_p10     INTEGER,
    horizon_7d_p50     INTEGER,
    horizon_7d_p90     INTEGER,
    horizon_14d_p10    INTEGER,
    horizon_14d_p50    INTEGER,
    horizon_14d_p90    INTEGER,
    horizon_30d_p10    INTEGER,
    horizon_30d_p50    INTEGER,
    horizon_30d_p90    INTEGER,
    model_version      VARCHAR(20)  NOT NULL,
    generated_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_forecasts PRIMARY KEY (forecast_id),
    CONSTRAINT uq_forecast UNIQUE (store_id, sku_id, as_of_date)
);

CREATE INDEX idx_forecasts_store_date
    ON :schema_name.demand_forecasts (store_id, as_of_date DESC);

-- ============================================================
-- END OF TENANT SCHEMA DDL
-- ============================================================
