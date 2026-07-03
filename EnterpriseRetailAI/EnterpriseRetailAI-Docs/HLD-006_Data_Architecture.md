# HLD-006 — Data Architecture
## EnterpriseRetailAI · Data Platform & Schema-per-Tenant Design

---

| Attribute | Value |
|---|---|
| Document ID | HLD-006 |
| Type | High-Level Design |
| Version | 1.0 |
| Status | Approved |
| Date | June 2026 |

---

## 1. Data Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      DATA PLATFORM LAYERS                               │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  INGESTION          STORE           PROCESS          SERVE              │
│  ┌──────────┐   ┌──────────┐   ┌──────────────┐  ┌──────────────┐      │
│  │POS Events│──►│Event Hubs│──►│Stream        │─►│Azure SQL     │      │
│  │Store Edge│   │(per      │   │Analytics     │  │(operational) │      │
│  │IoT Telem.│   │ tenant)  │   │(CRDT merge)  │  │              │      │
│  └──────────┘   └────┬─────┘   └──────────────┘  └──────────────┘      │
│                      │                                                   │
│                      │         ┌──────────────┐  ┌──────────────┐      │
│                      └────────►│ ADLS Gen2    │─►│ Synapse      │      │
│                                │ (raw events) │  │ Analytics    │      │
│                                │              │  │ (BI + ML     │      │
│                                │              │  │  training)   │      │
│                                └──────────────┘  └──────────────┘      │
│                                                                          │
│  GOVERNANCE                                                              │
│  Azure Purview: data catalog, lineage, classification, PII detection    │
│  Azure Policy: data residency enforcement per tenant region              │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Schema-per-Tenant Design

Each franchisee is isolated at the PostgreSQL schema level:

```sql
-- Connection string uses tenant-specific credentials:
-- postgresql://svc_tenant_042@server.postgres.database.azure.com/retailai
-- The DB user svc_tenant_042 has USAGE on schema tenant_042 only

-- Schema bootstrap (run during tenant provisioning):
CREATE SCHEMA tenant_042;
GRANT USAGE ON SCHEMA tenant_042 TO svc_tenant_042;
ALTER DEFAULT PRIVILEGES IN SCHEMA tenant_042 
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO svc_tenant_042;

-- Row-level security double-lock:
ALTER TABLE tenant_042.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_policy ON tenant_042.transactions
  USING (tenant_id = current_setting('app.tenant_id')::uuid);
```

### Tenant Isolation Enforcement Matrix

| Layer | Control | Enforced By |
|---|---|---|
| DB user | Schema-scoped, no cross-schema grants | PostgreSQL RBAC |
| Connection | Credentials from Key Vault per tenant | AKS workload identity |
| Application | TenantContext middleware injects schema into every query | .NET / Java ORM |
| API | JWT tenant_id claim validated on every request | Azure APIM policy |
| Network | Private Endpoint per DB server; tenant VNET tagging | Azure Networking |
| Audit | Every query logged with tenant_id | PgAudit extension |

---

## 3. Data Domains & Ownership

| Domain | Tables | Owner | Sensitivity | Residency |
|---|---|---|---|---|
| Transactions | transactions, transaction_lines, voids, returns | Franchisee | PCI-DSS | Jurisdiction |
| Payments | payment_records, offline_tokens, settlements | Franchisee | PCI-DSS (CDE) | Jurisdiction |
| Customers | customers, customer_consent, customer_segments | Franchisee | GDPR/CCPA | Country |
| Inventory | inventory, inventory_movements, stock_alerts | Franchisee | Low-Medium | Regional |
| Loyalty | loyalty_accounts, loyalty_transactions, rewards | Franchisee | GDPR | Country |
| Products | products, product_prices, product_overrides | HQ + Franchisee | Low | None |
| Staff | staff, roles, shifts, attendance | Franchisee | Personal Data | Jurisdiction |
| AI/Features | ml_features, model_predictions, feedback | HQ + Franchisee | Medium | Per DPA |
| Audit | audit_log, consent_records, erasure_requests | HQ (immutable) | Compliance | Retain 7y |
| Telemetry | device_telemetry, store_health | HQ | Low | None |

---

## 4. Event Sourcing Pattern

All state changes in the POS system are modelled as immutable events:

```
Event Schema (Avro):
{
  "event_id":        "uuid-v7",          // time-sortable UUID
  "event_type":      "transaction.completed",
  "tenant_id":       "uuid",
  "store_id":        "uuid",
  "pos_id":          "uuid",
  "idempotency_key": "uuid-v4",          // used for deduplication
  "timestamp":       "ISO8601 UTC",
  "vector_clock":    {"pos_042": 1042},  // CRDT merge key
  "payload":         { ... }             // event-type specific
}

Event types:
  transaction.completed      transaction.voided
  transaction.line.added     transaction.line.removed
  payment.processed          payment.failed
  payment.token.created      payment.token.settled
  inventory.adjusted         inventory.alert.raised
  loyalty.accrued            loyalty.redeemed
  promotion.applied          promotion.declined
  customer.consent.granted   customer.consent.withdrawn
  shift.opened               shift.closed
  device.telemetry.reported
```

---

## 5. Master Data Management

| Entity | Golden Record | Sync Method | Offline Cache |
|---|---|---|---|
| Product (SKU) | HQ CosmosDB | Global replication | Full copy: Store Edge + POS |
| Pricing | HQ + Franchisee override | Service Bus push (change events) | Full: POS SQLite |
| Promotions | HQ + Franchisee override | Service Bus push + IoT Edge | Full: POS SQLite |
| Tax rates | HQ (per jurisdiction) | Config service (scheduled) | Full: POS SQLite |
| Customer | Franchisee (GDPR-scoped) | Event-driven CDC | Hash only: POS |
| Staff | Franchisee | AAD sync | Hashed creds: POS |
| FX rates | HQ (FX API) | Scheduled push (15 min) | Last-known: POS |
| Store config | Franchisee | CosmosDB (on-read) | Full: Store Edge |

---

## 6. Data Retention & Lifecycle

| Data Type | Hot Storage | Cool Archive | Legal Hold | Delete |
|---|---|---|---|---|
| Transaction events | 90 days (ADLS Hot) | 1-7 years (Cool/Archive) | 7 years (financial) | After 7 years |
| Customer PII | Duration of consent | — | Per regulation | On erasure request |
| Payment records | 90 days | 7 years (compliance) | 7 years (PCI) | After 7 years |
| Audit logs | 1 year | 6 years (immutable blob) | 7 years | Never (immutable) |
| ML training data | 90 days | 3 years | Per DPA | On tenant offboarding |
| Device telemetry | 30 days | 1 year | — | After 1 year |

---

## 7. GDPR Right to Erasure Pipeline

```
Erasure Request Received (portal / API / DPA obligation)
    │
Identity Verification (AAD B2C: email OTP)
    │
Erasure Orchestrator (Azure Durable Function):
Step 1: Tenant SQL schema → NULL PII columns, flag customer_id as ERASED
Step 2: Event Hub historical events → replace PII fields with [REDACTED]
Step 3: ADLS Gen2 → delete customer from feature store parquet files
Step 4: Synapse → purge from BI datasets (next ETL cycle)
Step 5: Edge stores → deletion command pushed via IoT Hub + Service Bus
Step 6: Redis cache → invalidate all cached customer data
    │
Erasure Certificate generated (PDF) → stored in Immutable Blob
Confirmation sent to customer within 24 hours
Audit record: retained 7 years (no PII, just event metadata)
```

---

## 8. Related Documents

| Document | Reference |
|---|---|
| Data Schema LLD | `02_LLD/LLD-013_Data_Schema_Design.md` |
| Event Sync CRDT LLD | `02_LLD/LLD-011_Event_Sync_CRDT_Engine.md` |
| Multitenancy HLD | `01_HLD/HLD-009_Multitenancy.md` |
| Security HLD | `01_HLD/HLD-007_Security_Compliance.md` |
