-- ============================================================
-- EnterpriseRetailAI · POS Local SQLite Schema DDL
-- File: 06_DB_Schemas/pos_local_sqlite_DDL.sql
-- Database: SQLite 3.44 (encrypted with SQLCipher AES-256-CBC)
-- Purpose: All tables stored locally on each POS terminal
-- Note: SQLite pragma settings MUST be applied at connection open
-- ============================================================

-- ============================================================
-- PRAGMA SETTINGS (apply at every new connection)
-- ============================================================
-- PRAGMA journal_mode = WAL;        -- enables concurrent reads
-- PRAGMA foreign_keys = ON;         -- enforce FK constraints
-- PRAGMA synchronous = NORMAL;      -- safe with WAL
-- PRAGMA cache_size = -8192;        -- 8MB page cache
-- PRAGMA temp_store = MEMORY;       -- temp tables in RAM
-- PRAGMA mmap_size = 268435456;     -- 256MB memory-mapped I/O
-- PRAGMA key = '<derived_from_tpm>';  -- SQLCipher passphrase (TPM-derived)

-- ============================================================
-- SECTION 1: TRANSACTIONS (append-only event log)
-- ============================================================

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id       TEXT     NOT NULL PRIMARY KEY,     -- UUID v7
    idempotency_key      TEXT     NOT NULL UNIQUE,          -- UUID v4
    tenant_id            TEXT     NOT NULL,
    store_id             TEXT     NOT NULL,
    pos_id               TEXT     NOT NULL,
    cashier_id           TEXT     NOT NULL,
    shift_id             TEXT     NOT NULL,
    state                TEXT     NOT NULL DEFAULT 'SCANNING'
        CHECK (state IN ('IDLE','SCANNING','TOTALLING','PAYMENT_PENDING',
                         'COMPLETING','COMPLETE','VOID','SUSPENDED')),
    opened_at            TEXT     NOT NULL,                  -- ISO8601 UTC
    completed_at         TEXT,
    voided_at            TEXT,
    void_reason          TEXT,
    customer_id          TEXT,
    loyalty_id           TEXT,
    currency             TEXT     NOT NULL DEFAULT 'GBP',
    subtotal_minor       INTEGER  NOT NULL DEFAULT 0,
    tax_total_minor      INTEGER  NOT NULL DEFAULT 0,
    discount_total_minor INTEGER  NOT NULL DEFAULT 0,
    grand_total_minor    INTEGER  NOT NULL DEFAULT 0,
    payment_method       TEXT,
    is_offline_tx        INTEGER  NOT NULL DEFAULT 0,       -- 0/1 boolean
    receipt_number       TEXT,
    fraud_score          REAL,
    fraud_decision       TEXT,
    synced               INTEGER  NOT NULL DEFAULT 0,       -- 0=pending, 1=synced
    synced_at            TEXT,
    created_at           TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_transactions_state
    ON transactions (state, created_at)
    WHERE state != 'COMPLETE';
CREATE INDEX IF NOT EXISTS idx_transactions_unsynced
    ON transactions (created_at)
    WHERE synced = 0;
CREATE INDEX IF NOT EXISTS idx_transactions_cashier
    ON transactions (cashier_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_shift
    ON transactions (shift_id);

-- ============================================================

CREATE TABLE IF NOT EXISTS transaction_lines (
    line_id              TEXT     NOT NULL PRIMARY KEY,
    transaction_id       TEXT     NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    sku_id               TEXT     NOT NULL,
    barcode              TEXT,
    product_name         TEXT     NOT NULL,
    category             TEXT,
    quantity             INTEGER  NOT NULL,
    unit_price_minor     INTEGER  NOT NULL,
    tax_rate_pct         REAL     NOT NULL DEFAULT 0.0,
    tax_amount_minor     INTEGER  NOT NULL DEFAULT 0,
    discount_amount_minor INTEGER NOT NULL DEFAULT 0,
    line_total_minor     INTEGER  NOT NULL,
    is_return_line       INTEGER  NOT NULL DEFAULT 0,
    original_line_id     TEXT,
    created_at           TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_lines_transaction ON transaction_lines (transaction_id);
CREATE INDEX IF NOT EXISTS idx_lines_sku ON transaction_lines (sku_id);

-- ============================================================
-- SECTION 2: PRODUCT CACHE (full catalogue copy)
-- ============================================================

CREATE TABLE IF NOT EXISTS product_cache (
    sku_id               TEXT     NOT NULL PRIMARY KEY,
    barcode              TEXT     NOT NULL UNIQUE,
    barcode_type         TEXT     NOT NULL DEFAULT 'EAN13',
    name                 TEXT     NOT NULL,
    category             TEXT     NOT NULL,
    subcategory          TEXT,
    brand                TEXT,
    base_price_minor     INTEGER  NOT NULL,
    tax_category         TEXT     NOT NULL DEFAULT 'standard',
    weight_grams         REAL,
    is_age_restricted    INTEGER  NOT NULL DEFAULT 0,
    age_restriction      INTEGER,
    is_weighable         INTEGER  NOT NULL DEFAULT 0,
    is_active            INTEGER  NOT NULL DEFAULT 1,
    image_url            TEXT,
    catalogue_version    TEXT     NOT NULL,
    cached_at            TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_product_barcode  ON product_cache (barcode);
CREATE INDEX IF NOT EXISTS idx_product_category ON product_cache (category);
CREATE VIRTUAL TABLE IF NOT EXISTS product_fts
    USING fts5(sku_id UNINDEXED, name, brand, category, content=product_cache, content_rowid=rowid);

-- ============================================================
-- SECTION 3: PRICING RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS price_rules (
    rule_id              TEXT     NOT NULL PRIMARY KEY,
    sku_id               TEXT,                              -- NULL = applies to category
    category             TEXT,
    store_id             TEXT,                              -- NULL = all stores
    override_price_minor INTEGER  NOT NULL,
    valid_from           TEXT     NOT NULL,
    valid_until          TEXT     NOT NULL,
    rule_version         INTEGER  NOT NULL DEFAULT 1,
    created_at           TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_price_rules_sku
    ON price_rules (sku_id, valid_from, valid_until)
    WHERE sku_id IS NOT NULL;

-- ============================================================
-- SECTION 4: PROMOTION RULES
-- ============================================================

CREATE TABLE IF NOT EXISTS promotion_rules (
    promo_id             TEXT     NOT NULL PRIMARY KEY,
    name                 TEXT     NOT NULL,
    discount_type        TEXT     NOT NULL,
    discount_value       REAL     NOT NULL,
    min_basket_minor     INTEGER  DEFAULT 0,
    max_discount_minor   INTEGER,
    applicable_skus      TEXT,                              -- JSON array
    applicable_categories TEXT,                             -- JSON array
    exclusive_group      TEXT,
    requires_loyalty     INTEGER  NOT NULL DEFAULT 0,
    valid_from           TEXT     NOT NULL,
    valid_until          TEXT     NOT NULL,
    customer_reason      TEXT,
    rule_version         INTEGER  NOT NULL DEFAULT 1,
    is_active            INTEGER  NOT NULL DEFAULT 1,
    created_at           TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_promo_rules_active
    ON promotion_rules (valid_from, valid_until)
    WHERE is_active = 1;

-- ============================================================
-- SECTION 5: TAX RATES
-- ============================================================

CREATE TABLE IF NOT EXISTS tax_rates (
    rate_id              TEXT     NOT NULL PRIMARY KEY,
    jurisdiction         TEXT     NOT NULL,
    tax_category         TEXT     NOT NULL,
    rate_pct             REAL     NOT NULL,
    effective_from       TEXT     NOT NULL,
    effective_until      TEXT,
    UNIQUE (jurisdiction, tax_category, effective_from)
);

-- ============================================================
-- SECTION 6: STAFF CREDENTIALS (hashed — no plaintext)
-- ============================================================

CREATE TABLE IF NOT EXISTS staff_credentials (
    staff_id             TEXT     NOT NULL PRIMARY KEY,
    display_name         TEXT     NOT NULL,
    role                 TEXT     NOT NULL,
    pin_hash             TEXT     NOT NULL,  -- PBKDF2-HMAC-SHA256, 600000 iterations
    pin_salt             TEXT     NOT NULL,
    is_active            INTEGER  NOT NULL DEFAULT 1,
    requires_mfa         INTEGER  NOT NULL DEFAULT 0,
    last_sync_at         TEXT     NOT NULL,
    cached_at            TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_staff_active ON staff_credentials (is_active) WHERE is_active = 1;

-- ============================================================
-- SECTION 7: LOYALTY CACHE
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty_cache (
    customer_id          TEXT     NOT NULL PRIMARY KEY,
    loyalty_number       TEXT     NOT NULL UNIQUE,
    points_balance       INTEGER  NOT NULL DEFAULT 0,
    tier                 TEXT     NOT NULL DEFAULT 'STANDARD',
    cached_at            TEXT     NOT NULL,
    is_stale             INTEGER  NOT NULL DEFAULT 0        -- 1 = needs refresh
);

CREATE TABLE IF NOT EXISTS loyalty_delta (
    delta_id             TEXT     NOT NULL PRIMARY KEY,
    customer_id          TEXT     NOT NULL,
    transaction_id       TEXT     NOT NULL,
    movement_type        TEXT     NOT NULL DEFAULT 'EARN',
    points_delta         INTEGER  NOT NULL,
    idempotency_key      TEXT     NOT NULL UNIQUE,
    synced               INTEGER  NOT NULL DEFAULT 0,
    created_at           TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_loyalty_delta_unsynced
    ON loyalty_delta (created_at)
    WHERE synced = 0;

-- ============================================================
-- SECTION 8: OFFLINE PAYMENT TOKENS (AES-256 encrypted blob)
-- ============================================================

CREATE TABLE IF NOT EXISTS offline_payment_tokens (
    token_id             TEXT     NOT NULL PRIMARY KEY,
    pos_id               TEXT     NOT NULL,
    shift_id             TEXT     NOT NULL,
    token_encrypted      BLOB     NOT NULL,                 -- AES-256-GCM ciphertext
    token_nonce          BLOB     NOT NULL,                 -- 12-byte GCM nonce
    amount_minor         INTEGER  NOT NULL,
    currency             TEXT     NOT NULL,
    card_type            TEXT     NOT NULL,
    expiry_at            TEXT     NOT NULL,
    status               TEXT     NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','SETTLED','EXPIRED','FAILED')),
    retry_count          INTEGER  NOT NULL DEFAULT 0,
    created_at           TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    settled_at           TEXT
);

CREATE INDEX IF NOT EXISTS idx_tokens_pending
    ON offline_payment_tokens (created_at)
    WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_tokens_expiry
    ON offline_payment_tokens (expiry_at)
    WHERE status = 'PENDING';

-- ============================================================
-- SECTION 9: EVENT OUTBOX (sync queue)
-- ============================================================

CREATE TABLE IF NOT EXISTS event_outbox (
    id                   TEXT     NOT NULL PRIMARY KEY,
    idempotency_key      TEXT     NOT NULL UNIQUE,
    event_type           TEXT     NOT NULL,
    payload              BLOB     NOT NULL,                 -- Avro-encoded, encrypted
    vector_clock         TEXT     NOT NULL,                 -- JSON {"POS-T01": 1042}
    created_at           TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    dispatched_at        TEXT,                              -- NULL = pending
    retry_count          INTEGER  NOT NULL DEFAULT 0,
    last_error           TEXT
);

CREATE INDEX IF NOT EXISTS idx_outbox_pending
    ON event_outbox (created_at ASC)
    WHERE dispatched_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_outbox_cleanup
    ON event_outbox (dispatched_at)
    WHERE dispatched_at IS NOT NULL;

-- ============================================================
-- SECTION 10: SYNC STATE (vector clocks)
-- ============================================================

CREATE TABLE IF NOT EXISTS sync_state (
    peer_id              TEXT     NOT NULL PRIMARY KEY,     -- POS-ID or STORE-EDGE
    peer_type            TEXT     NOT NULL DEFAULT 'STORE_EDGE',
    last_vector_clock    TEXT     NOT NULL DEFAULT '{}',    -- JSON
    last_sync_at         TEXT,
    last_ack_event_id    TEXT,
    online               INTEGER  NOT NULL DEFAULT 0
);

-- ============================================================
-- SECTION 11: SHIFTS
-- ============================================================

CREATE TABLE IF NOT EXISTS shifts (
    shift_id             TEXT     NOT NULL PRIMARY KEY,
    cashier_id           TEXT     NOT NULL,
    pos_id               TEXT     NOT NULL,
    opened_at            TEXT     NOT NULL,
    closed_at            TEXT,
    opening_float_minor  INTEGER  NOT NULL DEFAULT 0,
    closing_float_minor  INTEGER,
    cash_variance_minor  INTEGER,
    tx_count             INTEGER  NOT NULL DEFAULT 0,
    gross_sales_minor    INTEGER  NOT NULL DEFAULT 0,
    status               TEXT     NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN','CLOSED')),
    synced               INTEGER  NOT NULL DEFAULT 0,
    created_at           TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_shifts_open ON shifts (status) WHERE status = 'OPEN';
CREATE INDEX IF NOT EXISTS idx_shifts_cashier ON shifts (cashier_id, opened_at DESC);

-- ============================================================
-- SECTION 12: ONNX MODEL REGISTRY (local)
-- ============================================================

CREATE TABLE IF NOT EXISTS model_registry (
    model_id             TEXT     NOT NULL PRIMARY KEY,
    use_case             TEXT     NOT NULL,
    version              TEXT     NOT NULL,
    file_path            TEXT     NOT NULL,
    sha256_hash          TEXT     NOT NULL,
    file_size_bytes      INTEGER  NOT NULL,
    is_active            INTEGER  NOT NULL DEFAULT 0,       -- only 1 active per use_case
    downloaded_at        TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE (use_case, version)
);

-- ============================================================
-- SECTION 13: CURRENCY FX RATES
-- ============================================================

CREATE TABLE IF NOT EXISTS fx_rates (
    rate_id              TEXT     NOT NULL PRIMARY KEY,
    from_currency        TEXT     NOT NULL,
    to_currency          TEXT     NOT NULL,
    rate                 REAL     NOT NULL,
    valid_at             TEXT     NOT NULL,
    cached_at            TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE (from_currency, to_currency, valid_at)
);

-- ============================================================
-- SECTION 14: APPLIED PROMOTIONS (for receipt + sync)
-- ============================================================

CREATE TABLE IF NOT EXISTS applied_promotions (
    applied_id           TEXT     NOT NULL PRIMARY KEY,
    transaction_id       TEXT     NOT NULL REFERENCES transactions(transaction_id) ON DELETE CASCADE,
    promo_id             TEXT     NOT NULL,
    promo_name           TEXT     NOT NULL,
    discount_type        TEXT     NOT NULL,
    discount_amount_minor INTEGER NOT NULL,
    ai_score             REAL,
    applied_at           TEXT     NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_applied_promos_tx ON applied_promotions (transaction_id);

-- ============================================================
-- SECTION 15: MAINTENANCE (nightly cleanup trigger)
-- ============================================================

-- Purge dispatched outbox events older than 7 days
-- (run during nightly maintenance window by POS application):
-- DELETE FROM event_outbox WHERE dispatched_at IS NOT NULL
--   AND datetime(dispatched_at) < datetime('now', '-7 days');

-- Purge settled/expired payment tokens older than 30 days:
-- DELETE FROM offline_payment_tokens WHERE status != 'PENDING'
--   AND datetime(created_at) < datetime('now', '-30 days');

-- ============================================================
-- END OF POS LOCAL SQLITE SCHEMA
-- ============================================================
