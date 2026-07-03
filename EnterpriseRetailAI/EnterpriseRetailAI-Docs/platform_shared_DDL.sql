-- ============================================================
-- EnterpriseRetailAI · Platform Shared Schema DDL
-- File: 06_DB_Schemas/platform_shared_DDL.sql
-- Database: PostgreSQL 16 (Azure SQL Flexible — platform server)
-- Purpose: Shared HQ-managed tables accessible to all tenants (read-only)
-- Schema: platform_shared
-- ============================================================

CREATE SCHEMA IF NOT EXISTS platform_shared;

-- ============================================================
-- SECTION 1: PRODUCT CATALOGUE (HQ Master)
-- ============================================================

CREATE TABLE platform_shared.products (
    sku_id             UUID         NOT NULL DEFAULT gen_random_uuid(),
    barcode            VARCHAR(50)  NOT NULL UNIQUE,
    barcode_type       VARCHAR(10)  NOT NULL DEFAULT 'EAN13'
        CHECK (barcode_type IN ('EAN13','UPC_A','UPC_E','QR','CODE128','DATAMATRIX')),
    name               VARCHAR(255) NOT NULL,
    description        TEXT,
    category           VARCHAR(100) NOT NULL,
    subcategory        VARCHAR(100),
    brand              VARCHAR(100),
    unit_of_measure    VARCHAR(20)  NOT NULL DEFAULT 'EACH',
    weight_grams       NUMERIC(10,3),
    dimensions_cm      JSONB,          -- {"l": 10, "w": 8, "h": 5}
    image_url          TEXT,
    thumbnail_url      TEXT,
    tax_category       VARCHAR(30)  NOT NULL DEFAULT 'standard',
    is_age_restricted  BOOLEAN      NOT NULL DEFAULT false,
    age_restriction    SMALLINT,       -- minimum age (e.g. 18)
    is_controlled      BOOLEAN      NOT NULL DEFAULT false, -- pharmacy/restricted
    is_weighable       BOOLEAN      NOT NULL DEFAULT false,
    is_active          BOOLEAN      NOT NULL DEFAULT true,
    is_seasonal        BOOLEAN      NOT NULL DEFAULT false,
    season_code        VARCHAR(20),
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_products PRIMARY KEY (sku_id)
);

CREATE INDEX idx_products_barcode   ON platform_shared.products (barcode);
CREATE INDEX idx_products_category  ON platform_shared.products (category, subcategory);
CREATE INDEX idx_products_brand     ON platform_shared.products (brand);
CREATE INDEX idx_products_active    ON platform_shared.products (is_active) WHERE is_active = true;

-- Full-text search index
CREATE INDEX idx_products_fts
    ON platform_shared.products
    USING gin(to_tsvector('english', coalesce(name,'') || ' ' || coalesce(brand,'') || ' ' || coalesce(description,'')));

-- ============================================================
-- SECTION 2: GLOBAL PRICING (HQ Master Prices)
-- ============================================================

CREATE TABLE platform_shared.product_prices (
    price_id           UUID         NOT NULL DEFAULT gen_random_uuid(),
    sku_id             UUID         NOT NULL REFERENCES platform_shared.products(sku_id),
    currency           CHAR(3)      NOT NULL,
    base_price_minor   BIGINT       NOT NULL CHECK (base_price_minor >= 0),
    effective_from     TIMESTAMPTZ  NOT NULL,
    effective_until    TIMESTAMPTZ,
    price_version      INTEGER      NOT NULL DEFAULT 1,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_product_prices PRIMARY KEY (price_id)
);

CREATE INDEX idx_prices_sku_currency
    ON platform_shared.product_prices (sku_id, currency, effective_from DESC);

-- ============================================================
-- SECTION 3: GLOBAL PROMOTIONS TEMPLATES (HQ Master)
-- ============================================================

CREATE TABLE platform_shared.promotion_templates (
    template_id        UUID         NOT NULL DEFAULT gen_random_uuid(),
    name               VARCHAR(255) NOT NULL,
    description        TEXT,
    discount_type      VARCHAR(20)  NOT NULL,
    discount_value     NUMERIC(10,4) NOT NULL,
    applicable_categories VARCHAR(100)[],
    applicable_skus    UUID[],
    exclusive_group    VARCHAR(50),
    is_global          BOOLEAN      NOT NULL DEFAULT false, -- auto-applied to all tenants
    valid_from         TIMESTAMPTZ  NOT NULL,
    valid_until        TIMESTAMPTZ  NOT NULL,
    is_active          BOOLEAN      NOT NULL DEFAULT true,
    customer_reason    VARCHAR(255),
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_promotion_templates PRIMARY KEY (template_id)
);

-- ============================================================
-- SECTION 4: TENANTS REGISTRY
-- ============================================================

CREATE TABLE platform_shared.tenants (
    tenant_id          UUID         NOT NULL DEFAULT gen_random_uuid(),
    franchisee_name    VARCHAR(255) NOT NULL,
    franchisee_code    VARCHAR(50)  NOT NULL UNIQUE,
    legal_entity       VARCHAR(255),
    status             VARCHAR(20)  NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING','ACTIVE','SUSPENDED','OFFBOARDING','TERMINATED')),
    plan               VARCHAR(20)  NOT NULL DEFAULT 'STANDARD'
        CHECK (plan IN ('STARTER','STANDARD','ENTERPRISE','CUSTOM')),
    primary_region     VARCHAR(50)  NOT NULL,
    db_schema_name     VARCHAR(100) NOT NULL UNIQUE,
    aad_app_id         UUID,
    aks_namespace      VARCHAR(100),
    event_hubs_ns      VARCHAR(100),
    onboarded_at       TIMESTAMPTZ,
    suspended_at       TIMESTAMPTZ,
    contract_expires   DATE,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_tenants PRIMARY KEY (tenant_id)
);

CREATE INDEX idx_tenants_status ON platform_shared.tenants (status);
CREATE INDEX idx_tenants_region ON platform_shared.tenants (primary_region);

-- ============================================================
-- SECTION 5: STORES REGISTRY
-- ============================================================

CREATE TABLE platform_shared.stores (
    store_id           UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID         NOT NULL REFERENCES platform_shared.tenants(tenant_id),
    store_name         VARCHAR(255) NOT NULL,
    store_code         VARCHAR(50)  NOT NULL,
    store_tier         VARCHAR(10)  NOT NULL DEFAULT 'TIER_B'
        CHECK (store_tier IN ('TIER_A','TIER_B','TIER_C')),
    address_line1      VARCHAR(255),
    address_city       VARCHAR(100),
    address_country    CHAR(2),
    timezone           VARCHAR(50)  NOT NULL DEFAULT 'UTC',
    currency           CHAR(3)      NOT NULL DEFAULT 'GBP',
    tax_jurisdiction   CHAR(3)      NOT NULL DEFAULT 'GBR',
    is_active          BOOLEAN      NOT NULL DEFAULT true,
    iot_hub_device_id  VARCHAR(100),
    edge_node_count    SMALLINT     NOT NULL DEFAULT 1,
    pos_count          SMALLINT     NOT NULL DEFAULT 0,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_stores PRIMARY KEY (store_id),
    CONSTRAINT uq_store_code UNIQUE (tenant_id, store_code)
);

CREATE INDEX idx_stores_tenant   ON platform_shared.stores (tenant_id) WHERE is_active = true;
CREATE INDEX idx_stores_country  ON platform_shared.stores (address_country);

-- ============================================================
-- SECTION 6: AI MODEL REGISTRY
-- ============================================================

CREATE TABLE platform_shared.ai_models (
    model_id           UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID,                   -- NULL = HQ baseline (all tenants)
    use_case           VARCHAR(30)  NOT NULL
        CHECK (use_case IN ('FRAUD_DETECTION','DEMAND_FORECAST','PERSONALISATION',
                             'CV_SELF_CHECKOUT','NLP_ASSISTANT','PREDICTIVE_MAINTENANCE')),
    model_name         VARCHAR(100) NOT NULL,
    model_version      VARCHAR(20)  NOT NULL,
    framework          VARCHAR(50)  NOT NULL,
    model_format       VARCHAR(20)  NOT NULL CHECK (model_format IN ('ONNX','GGUF','PICKLE','PYTORCH','MLFLOW')),
    sha256_hash        CHAR(64)     NOT NULL,
    file_size_mb       NUMERIC(8,2),
    deployment_targets VARCHAR(10)[] NOT NULL DEFAULT '{cloud}',
    status             VARCHAR(20)  NOT NULL DEFAULT 'STAGED'
        CHECK (status IN ('STAGED','CANARY','PRODUCTION','DEPRECATED','ARCHIVED')),
    kpi_metrics        JSONB,
    model_card         JSONB,
    registered_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    approved_by        UUID,
    approved_at        TIMESTAMPTZ,
    deployed_at        TIMESTAMPTZ,
    CONSTRAINT pk_ai_models PRIMARY KEY (model_id)
);

CREATE INDEX idx_models_tenant_usecase
    ON platform_shared.ai_models (tenant_id, use_case, status);

-- ============================================================
-- SECTION 7: GLOBAL TAX RULES
-- ============================================================

CREATE TABLE platform_shared.global_tax_rates (
    rate_id            UUID         NOT NULL DEFAULT gen_random_uuid(),
    jurisdiction       CHAR(3)      NOT NULL,
    tax_category       VARCHAR(30)  NOT NULL,
    rate_pct           NUMERIC(6,4) NOT NULL,
    effective_from     DATE         NOT NULL,
    effective_until    DATE,
    source             VARCHAR(50),    -- e.g. "HMRC 2026-04"
    CONSTRAINT pk_global_tax PRIMARY KEY (rate_id),
    CONSTRAINT uq_global_tax UNIQUE (jurisdiction, tax_category, effective_from)
);

-- ============================================================
-- SECTION 8: PROVISIONING AUDIT (Immutable)
-- ============================================================

CREATE TABLE platform_shared.provisioning_audit (
    audit_id           UUID         NOT NULL DEFAULT gen_random_uuid(),
    tenant_id          UUID,
    store_id           UUID,
    job_id             UUID         NOT NULL,
    step_name          VARCHAR(100) NOT NULL,
    status             VARCHAR(10)  NOT NULL CHECK (status IN ('STARTED','SUCCESS','FAILED','SKIPPED')),
    duration_ms        INTEGER,
    error_message      TEXT,
    performed_by       UUID,
    event_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_prov_audit PRIMARY KEY (audit_id)
);

CREATE INDEX idx_prov_audit_tenant ON platform_shared.provisioning_audit (tenant_id, event_at DESC);
CREATE INDEX idx_prov_audit_job    ON platform_shared.provisioning_audit (job_id);

-- ============================================================
-- SECTION 9: PLATFORM EVENTS (cross-tenant operational)
-- ============================================================

CREATE TABLE platform_shared.platform_events (
    event_id           UUID         NOT NULL DEFAULT gen_random_uuid(),
    event_type         VARCHAR(100) NOT NULL,
    severity           VARCHAR(10)  NOT NULL CHECK (severity IN ('INFO','WARNING','CRITICAL')),
    tenant_id          UUID,
    store_id           UUID,
    device_id          VARCHAR(100),
    summary            TEXT         NOT NULL,
    payload            JSONB,
    resolved           BOOLEAN      NOT NULL DEFAULT false,
    resolved_at        TIMESTAMPTZ,
    event_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_platform_events PRIMARY KEY (event_id)
);

CREATE INDEX idx_platform_events_type     ON platform_shared.platform_events (event_type, event_at DESC);
CREATE INDEX idx_platform_events_severity ON platform_shared.platform_events (severity, resolved, event_at DESC);

-- ============================================================
-- SECTION 10: READ-ONLY GRANTS (all tenant app users)
-- ============================================================

-- Grant read access to platform_shared for all tenant service accounts
-- (executed per tenant during provisioning):
-- GRANT USAGE ON SCHEMA platform_shared TO svc_tenant_{id};
-- GRANT SELECT ON ALL TABLES IN SCHEMA platform_shared TO svc_tenant_{id};
-- ALTER DEFAULT PRIVILEGES IN SCHEMA platform_shared
--     GRANT SELECT ON TABLES TO svc_tenant_{id};

-- ============================================================
-- END OF PLATFORM SHARED SCHEMA DDL
-- ============================================================
