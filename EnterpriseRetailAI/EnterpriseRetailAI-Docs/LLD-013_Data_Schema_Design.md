# LLD-013 — Data Schema Design
## EnterpriseRetailAI · Full PostgreSQL DDL, SQLite Schema, Indexes, RLS

---

| Document ID | LLD-013 | Version | 1.0 | Status | Approved |

---

## 1. Tenant Schema DDL (PostgreSQL 16)

All tables below are created inside `tenant_{franchisee_id}` schema.

---

### 1.1 Transactions

```sql
-- ============================================================
-- TRANSACTIONS
-- ============================================================
CREATE TABLE transactions (
    transaction_id       UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id            UUID         NOT NULL,
    store_id             UUID         NOT NULL,
    pos_id               UUID         NOT NULL,
    cashier_id           UUID         NOT NULL,
    shift_id             UUID         NOT NULL,
    idempotency_key      UUID         NOT NULL,
    state                VARCHAR(20)  NOT NULL
        CHECK (state IN ('COMPLETE','VOIDED','SUSPENDED','REFUNDED')),
    opened_at            TIMESTAMPTZ  NOT NULL,
    completed_at         TIMESTAMPTZ,
    voided_at            TIMESTAMPTZ,
    void_reason          TEXT,
    void_authorised_by   UUID,
    customer_id          UUID,                    -- FK to customers (nullable)
    loyalty_id           VARCHAR(50),
    currency             CHAR(3)      NOT NULL DEFAULT 'GBP',
    subtotal_minor       BIGINT       NOT NULL DEFAULT 0,   -- in minor units (pence)
    tax_total_minor      BIGINT       NOT NULL DEFAULT 0,
    discount_total_minor BIGINT       NOT NULL DEFAULT 0,
    grand_total_minor    BIGINT       NOT NULL DEFAULT 0,
    line_count           SMALLINT     NOT NULL DEFAULT 0,
    quantity_total       INTEGER      NOT NULL DEFAULT 0,
    payment_method       VARCHAR(30),
    is_offline_tx        BOOLEAN      NOT NULL DEFAULT false,
    receipt_number       VARCHAR(50),
    notes                TEXT,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_transactions PRIMARY KEY (transaction_id),
    CONSTRAINT uq_transactions_idempotency UNIQUE (idempotency_key)
);

CREATE INDEX idx_transactions_store_date
    ON transactions (store_id, completed_at DESC)
    WHERE state = 'COMPLETE';

CREATE INDEX idx_transactions_cashier
    ON transactions (cashier_id, opened_at DESC);

CREATE INDEX idx_transactions_customer
    ON transactions (customer_id)
    WHERE customer_id IS NOT NULL;

CREATE INDEX idx_transactions_created_at
    ON transactions (created_at DESC);

-- RLS
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_transactions ON transactions
    USING (tenant_id = current_setting('app.tenant_id')::uuid);


-- ============================================================
-- TRANSACTION LINES
-- ============================================================
CREATE TABLE transaction_lines (
    line_id              UUID         NOT NULL DEFAULT gen_random_uuid(),
    transaction_id       UUID         NOT NULL REFERENCES transactions(transaction_id)
                             ON DELETE CASCADE,
    tenant_id            UUID         NOT NULL,
    sku_id               UUID         NOT NULL,
    barcode              VARCHAR(50),
    product_name         VARCHAR(255) NOT NULL,
    category             VARCHAR(100),
    quantity             INTEGER      NOT NULL CHECK (quantity > 0),
    unit_price_minor     BIGINT       NOT NULL,
    tax_rate_pct         NUMERIC(6,4) NOT NULL DEFAULT 0,
    tax_amount_minor     BIGINT       NOT NULL DEFAULT 0,
    discount_amount_minor BIGINT      NOT NULL DEFAULT 0,
    line_total_minor     BIGINT       NOT NULL,
    is_return_line       BOOLEAN      NOT NULL DEFAULT false,
    original_line_id     UUID,                  -- for return lines
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_transaction_lines PRIMARY KEY (line_id)
);

CREATE INDEX idx_tx_lines_transaction
    ON transaction_lines (transaction_id);

CREATE INDEX idx_tx_lines_sku
    ON transaction_lines (sku_id, created_at DESC);

ALTER TABLE transaction_lines ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_transaction_lines ON transaction_lines
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

---

### 1.2 Customers (PII — GDPR Scoped)

```sql
-- ============================================================
-- CUSTOMERS  (PII — encrypt at column level for PAN proxies)
-- ============================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE customers (
    customer_id          UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id            UUID         NOT NULL,
    loyalty_number       VARCHAR(50)  UNIQUE,
    email_hash           BYTEA,       -- SHA-256(email) — no plaintext
    email_encrypted      BYTEA,       -- pgp_sym_encrypt(email, cmk)
    first_name_encrypted BYTEA,       -- pgp_sym_encrypt(first_name, cmk)
    last_name_encrypted  BYTEA,
    phone_encrypted      BYTEA,
    date_of_birth        DATE,        -- retained for age-gating only
    country_code         CHAR(2)      NOT NULL,
    preferred_language   CHAR(5)      DEFAULT 'en-GB',
    is_erased            BOOLEAN      NOT NULL DEFAULT false,
    consent_marketing    BOOLEAN      NOT NULL DEFAULT false,
    consent_personalised BOOLEAN      NOT NULL DEFAULT false,
    consent_data_sharing BOOLEAN      NOT NULL DEFAULT false,
    consent_updated_at   TIMESTAMPTZ,
    segment_code         VARCHAR(20),          -- ML-assigned segment
    rfm_score            NUMERIC(4,2),         -- recency-frequency-monetary
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
);

CREATE INDEX idx_customers_loyalty ON customers (loyalty_number)
    WHERE loyalty_number IS NOT NULL AND NOT is_erased;

CREATE INDEX idx_customers_email_hash ON customers (email_hash)
    WHERE email_hash IS NOT NULL AND NOT is_erased;

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_customers ON customers
    USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

---

### 1.3 Inventory

```sql
-- ============================================================
-- INVENTORY (current stock levels)
-- ============================================================
CREATE TABLE inventory (
    inventory_id    UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       UUID         NOT NULL,
    store_id        UUID         NOT NULL,
    sku_id          UUID         NOT NULL,
    quantity_on_hand INTEGER     NOT NULL DEFAULT 0 CHECK (quantity_on_hand >= 0),
    quantity_reserved INTEGER    NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
    quantity_in_transit INTEGER  NOT NULL DEFAULT 0,
    reorder_point   INTEGER,
    reorder_qty     INTEGER,
    last_count_at   TIMESTAMPTZ,
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    version         BIGINT       NOT NULL DEFAULT 1,   -- optimistic locking
    CONSTRAINT pk_inventory PRIMARY KEY (inventory_id),
    CONSTRAINT uq_inventory_store_sku UNIQUE (store_id, sku_id)
);

CREATE INDEX idx_inventory_store ON inventory (store_id, sku_id);
CREATE INDEX idx_inventory_low_stock ON inventory (store_id, quantity_on_hand)
    WHERE quantity_on_hand <= reorder_point;

-- Inventory movements audit trail
CREATE TABLE inventory_movements (
    movement_id     UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       UUID         NOT NULL,
    store_id        UUID         NOT NULL,
    sku_id          UUID         NOT NULL,
    movement_type   VARCHAR(20)  NOT NULL
        CHECK (movement_type IN ('SALE','RETURN','RECEIPT','ADJUSTMENT',
                                  'TRANSFER_IN','TRANSFER_OUT','SHRINKAGE')),
    quantity_delta  INTEGER      NOT NULL,
    reference_id    UUID,               -- transaction_id / PO_id etc.
    performed_by    UUID,
    notes           TEXT,
    movement_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_inventory_movements PRIMARY KEY (movement_id)
);

CREATE INDEX idx_inv_movements_store_sku
    ON inventory_movements (store_id, sku_id, movement_at DESC);
```

---

### 1.4 Loyalty

```sql
-- ============================================================
-- LOYALTY ACCOUNTS
-- ============================================================
CREATE TABLE loyalty_accounts (
    account_id      UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       UUID         NOT NULL,
    customer_id     UUID         NOT NULL REFERENCES customers(customer_id),
    loyalty_number  VARCHAR(50)  NOT NULL UNIQUE,
    points_balance  BIGINT       NOT NULL DEFAULT 0 CHECK (points_balance >= 0),
    tier            VARCHAR(20)  NOT NULL DEFAULT 'STANDARD'
        CHECK (tier IN ('STANDARD','SILVER','GOLD','PLATINUM')),
    tier_qualified_at TIMESTAMPTZ,
    lifetime_points BIGINT       NOT NULL DEFAULT 0,
    is_active       BOOLEAN      NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_loyalty_accounts PRIMARY KEY (account_id)
);

CREATE TABLE loyalty_transactions (
    lt_id           UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id       UUID         NOT NULL,
    account_id      UUID         NOT NULL REFERENCES loyalty_accounts(account_id),
    transaction_id  UUID,               -- reference to retail transaction
    movement_type   VARCHAR(10)  NOT NULL CHECK (movement_type IN ('EARN','BURN','EXPIRE','ADJUST')),
    points_delta    BIGINT       NOT NULL,
    points_balance_after BIGINT  NOT NULL,
    expiry_date     DATE,               -- for EARN records
    notes           TEXT,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_loyalty_transactions PRIMARY KEY (lt_id)
);

CREATE INDEX idx_loyalty_acct_customer ON loyalty_accounts(customer_id);
CREATE INDEX idx_loyalty_tx_account ON loyalty_transactions(account_id, created_at DESC);
```

---

### 1.5 Payments (PCI-DSS CDE Scope)

```sql
-- ============================================================
-- PAYMENT RECORDS  (PCI-DSS CDE — separate schema on separate server)
-- ============================================================
CREATE TABLE payment_records (
    payment_id       UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id        UUID         NOT NULL,
    transaction_id   UUID         NOT NULL,
    payment_method   VARCHAR(20)  NOT NULL
        CHECK (payment_method IN ('EMV_CHIP','CONTACTLESS','QR','CASH',
                                   'GIFT_CARD','SPLIT','OFFLINE_TOKEN')),
    amount_minor     BIGINT       NOT NULL,
    currency         CHAR(3)      NOT NULL,
    token_reference  VARCHAR(255),       -- gateway token (no PAN)
    auth_code        VARCHAR(20),
    gateway_ref      VARCHAR(100),
    is_offline       BOOLEAN      NOT NULL DEFAULT false,
    offline_token_id UUID,
    status           VARCHAR(20)  NOT NULL DEFAULT 'APPROVED'
        CHECK (status IN ('APPROVED','DECLINED','PENDING_SETTLEMENT',
                           'SETTLED','REFUNDED','DISPUTED')),
    processed_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    settled_at       TIMESTAMPTZ,
    CONSTRAINT pk_payment_records PRIMARY KEY (payment_id)
);

CREATE TABLE offline_payment_tokens (
    token_id         UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id        UUID         NOT NULL,
    pos_id           UUID         NOT NULL,
    token_value      BYTEA        NOT NULL,   -- encrypted HMAC token
    amount_minor     BIGINT       NOT NULL,
    currency         CHAR(3)      NOT NULL,
    expiry_at        TIMESTAMPTZ  NOT NULL,
    status           VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','SETTLED','EXPIRED','FAILED')),
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    settled_at       TIMESTAMPTZ,
    CONSTRAINT pk_offline_tokens PRIMARY KEY (token_id)
);
```

---

### 1.6 Shifts & Audit

```sql
CREATE TABLE shifts (
    shift_id         UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id        UUID         NOT NULL,
    store_id         UUID         NOT NULL,
    pos_id           UUID         NOT NULL,
    cashier_id       UUID         NOT NULL,
    opened_at        TIMESTAMPTZ  NOT NULL,
    closed_at        TIMESTAMPTZ,
    opening_float_minor BIGINT    NOT NULL DEFAULT 0,
    closing_float_minor BIGINT,
    cash_variance_minor BIGINT,
    tx_count         INTEGER      NOT NULL DEFAULT 0,
    gross_sales_minor BIGINT      NOT NULL DEFAULT 0,
    status           VARCHAR(20)  NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN','CLOSED','RECONCILED')),
    CONSTRAINT pk_shifts PRIMARY KEY (shift_id)
);

-- Immutable audit log
CREATE TABLE audit_log (
    audit_id     UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id    UUID         NOT NULL,
    event_type   VARCHAR(100) NOT NULL,
    actor_id     UUID,
    actor_type   VARCHAR(20),     -- USER, SERVICE, DEVICE
    resource_id  UUID,
    resource_type VARCHAR(50),
    action       VARCHAR(50)  NOT NULL,
    outcome      VARCHAR(10)  NOT NULL CHECK (outcome IN ('SUCCESS','FAILURE')),
    ip_address   INET,
    user_agent   TEXT,
    payload_hash BYTEA,          -- SHA-256 of event payload (not payload itself)
    event_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_audit_log PRIMARY KEY (audit_id)
);

-- audit_log is append-only: no UPDATE/DELETE grants given to application user
CREATE INDEX idx_audit_event_at ON audit_log (event_at DESC);
CREATE INDEX idx_audit_actor    ON audit_log (actor_id, event_at DESC);
```

---

## 2. POS Local SQLite Schema

```sql
-- SQLite 3.44 — SQLCipher AES-256-CBC encrypted

CREATE TABLE IF NOT EXISTS transactions (
    transaction_id    TEXT NOT NULL PRIMARY KEY,
    idempotency_key   TEXT NOT NULL UNIQUE,
    state             TEXT NOT NULL,
    opened_at         TEXT NOT NULL,
    completed_at      TEXT,
    grand_total_minor INTEGER NOT NULL DEFAULT 0,
    currency          TEXT NOT NULL DEFAULT 'GBP',
    payment_method    TEXT,
    is_offline_tx     INTEGER NOT NULL DEFAULT 0,
    synced            INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS transaction_lines (
    line_id           TEXT NOT NULL PRIMARY KEY,
    transaction_id    TEXT NOT NULL REFERENCES transactions(transaction_id),
    sku_id            TEXT NOT NULL,
    barcode           TEXT,
    product_name      TEXT NOT NULL,
    quantity          INTEGER NOT NULL,
    unit_price_minor  INTEGER NOT NULL,
    tax_amount_minor  INTEGER NOT NULL DEFAULT 0,
    line_total_minor  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_lines_tx ON transaction_lines(transaction_id);

CREATE TABLE IF NOT EXISTS product_cache (
    sku_id            TEXT NOT NULL PRIMARY KEY,
    barcode           TEXT UNIQUE,
    name              TEXT NOT NULL,
    category          TEXT,
    base_price_minor  INTEGER NOT NULL,
    tax_category      TEXT NOT NULL DEFAULT 'standard',
    is_active         INTEGER NOT NULL DEFAULT 1,
    updated_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_product_barcode ON product_cache(barcode);

CREATE TABLE IF NOT EXISTS price_rules (
    rule_id           TEXT NOT NULL PRIMARY KEY,
    sku_id            TEXT,
    category          TEXT,
    override_price_minor INTEGER NOT NULL,
    valid_from        TEXT NOT NULL,
    valid_until       TEXT NOT NULL,
    rule_version      INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS promotion_rules (
    promo_id          TEXT NOT NULL PRIMARY KEY,
    name              TEXT NOT NULL,
    discount_type     TEXT NOT NULL,
    discount_value    REAL NOT NULL,
    min_basket_minor  INTEGER DEFAULT 0,
    valid_from        TEXT NOT NULL,
    valid_until       TEXT NOT NULL,
    exclusive_group   TEXT,
    rule_data         TEXT NOT NULL,  -- JSON
    promo_version     INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS tax_rates (
    rate_id           TEXT NOT NULL PRIMARY KEY,
    jurisdiction      TEXT NOT NULL,
    tax_category      TEXT NOT NULL,
    rate_pct          REAL NOT NULL,
    effective_from    TEXT NOT NULL,
    UNIQUE (jurisdiction, tax_category)
);

CREATE TABLE IF NOT EXISTS staff_credentials (
    staff_id          TEXT NOT NULL PRIMARY KEY,
    display_name      TEXT NOT NULL,
    pin_hash          TEXT NOT NULL,  -- PBKDF2-HMAC-SHA256, 600000 iterations
    pin_salt          TEXT NOT NULL,
    role              TEXT NOT NULL,
    is_active         INTEGER NOT NULL DEFAULT 1,
    last_sync         TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS loyalty_delta (
    delta_id          TEXT NOT NULL PRIMARY KEY,
    customer_id       TEXT NOT NULL,
    transaction_id    TEXT NOT NULL,
    points_earned     INTEGER NOT NULL,
    created_at        TEXT NOT NULL,
    synced            INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS offline_payment_tokens (
    token_id          TEXT NOT NULL PRIMARY KEY,
    pos_id            TEXT NOT NULL,
    token_value       BLOB NOT NULL,  -- AES-256-GCM encrypted
    amount_minor      INTEGER NOT NULL,
    currency          TEXT NOT NULL,
    expiry_at         TEXT NOT NULL,
    status            TEXT NOT NULL DEFAULT 'PENDING',
    created_at        TEXT NOT NULL,
    settled_at        TEXT
);

CREATE TABLE IF NOT EXISTS event_outbox (
    id                TEXT NOT NULL PRIMARY KEY,
    idempotency_key   TEXT NOT NULL UNIQUE,
    event_type        TEXT NOT NULL,
    payload           BLOB NOT NULL,
    vector_clock      TEXT NOT NULL,
    created_at        TEXT NOT NULL,
    dispatched_at     TEXT,
    retry_count       INTEGER NOT NULL DEFAULT 0,
    last_error        TEXT
);
CREATE INDEX IF NOT EXISTS idx_outbox_pending
    ON event_outbox(dispatched_at, created_at)
    WHERE dispatched_at IS NULL;

CREATE TABLE IF NOT EXISTS sync_state (
    peer_id           TEXT NOT NULL PRIMARY KEY,
    last_vector_clock TEXT NOT NULL,
    last_sync_at      TEXT NOT NULL
);
```

---

## 3. Key Design Decisions

| Decision | Rationale |
|---|---|
| Minor units (integer pence/cents) for money | Avoids floating-point rounding errors in financial calculations |
| UUID v4 primary keys | No ordering dependency; globally unique across POS devices |
| Idempotency keys (UNIQUE constraint) | Prevents duplicate transaction inserts during retry storms |
| Append-only audit_log | No application-layer DELETE grants; immutable compliance evidence |
| Column-level encryption for PII | Defence-in-depth; protects PII even if DB admin access compromised |
| Optimistic locking (version column) on inventory | Handles concurrent updates from multiple POS without distributed locks |
| SQLCipher on POS SQLite | Full database encryption at rest on POS device; single passphrase from TPM |

---

## 4. Related Documents

- LLD-001: POS Transaction Engine (entity usage)
- LLD-002: Offline Sync Agent (outbox schema)
- HLD-006: Data Architecture
- LLD-012: Payment Service
