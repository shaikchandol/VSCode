# SKILL.md — Data Architecture, Schemas & Multiregional Design

**Skill Name:** data-architecture

**Purpose:** Help AI agents understand database design, schema-per-tenant isolation, data flows, multiregional replication, backup/recovery strategies, and data residency requirements.

---

## When to Use This Skill

Use this skill when:
- **Schema design questions** — "How are the tenant and platform shared schemas structured?"
- **Multiregional data** — "How do we keep EU data in Europe and US data in US?"
- **Data flows** — "How does data flow from POS → Store Edge → Cloud?"
- **Backup & recovery** — "What's our backup strategy? How do we recover from data loss?"
- **Data residency** — "Which data must stay in-region (GDPR, DPDP, PIPL)?"
- **Partitioning & indexing** — "How do we optimize queries across large tables?"
- **Schema evolution** — "How do we add columns without downtime?"
- **Replication strategies** — "How is data replicated across regions?"

Do NOT use this skill for:
- SQL query optimization (code-level)
- Specific performance tuning (use performance-scaling skill)
- Application-level ORM decisions

---

## Core Concepts

### 1. Schema-Per-Tenant Isolation (Not RLS)

**Traditional RLS (Row-Level Security):**
```
PostgreSQL Database
└─ Single schema "public"
   ├─ Table: customers (with tenant_id column)
   ├─ Table: transactions (with tenant_id column)
   └─ RLS Policy: WHERE tenant_id = current_user_tenant
   
Risk: Bug in RLS filter → Tenant A sees Tenant B data
```

**EnterpriseRetailAI Schema-Per-Tenant:**
```
PostgreSQL Database
├─ Schema: platform_shared (cross-tenant metadata)
│  └─ Tables: tenant_metadata, audit_log, subscriptions
├─ Schema: tenant_001 (Tenant 1)
│  └─ Tables: customers, transactions, inventory, employees
├─ Schema: tenant_002 (Tenant 2)
│  └─ Tables: customers, transactions, inventory, employees
└─ Schema: tenant_N (Tenant N)
   └─ Tables: customers, transactions, inventory, employees

Security: Separate schema = PostgreSQL enforces isolation
└─ Role "tenant_001_user" has GRANT only on tenant_001 schema
└─ Role "tenant_002_user" has GRANT only on tenant_002 schema
└─ No cross-tenant access possible (DB-level enforcement)
```

**Benefits:**
- ✅ GDPR: DELETE SCHEMA tenant_001 = instant deletion
- ✅ Compliance: Different schemas for different regions
- ✅ Customization: Each tenant can have custom fields
- ✅ Performance: Independent indexes, statistics per schema
- ✅ Audit: Separate connections per tenant (easier to track)

**Reference:** [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [LLD-013_Data_Schema_Design.md](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md)

---

## Database Topology

### Multi-Layer Schema Architecture

```
CLOUD (Azure SQL / PostgreSQL)
├─ Tenant_EU (westeurope region) — GDPR compliant
│  ├─ Schema: tenant_001, tenant_002, tenant_003 (EU tenants)
│  └─ Replicated: On-premises → Disk backup (geo-redundant)
│
├─ Tenant_US (eastus region) — CCPA compliant
│  ├─ Schema: tenant_004, tenant_005, tenant_006 (US tenants)
│  └─ Replicated: On-premises → Disk backup (geo-redundant)
│
└─ Tenant_APAC (southeastasia region) — DPDP compliant
   ├─ Schema: tenant_007, tenant_008 (India tenants)
   └─ Schema: tenant_009 (China - separate instance, no export)

STORE EDGE (On-Premises PostgreSQL)
├─ Sync staging tables (events from POS awaiting cloud sync)
├─ Local feature store (ML features for offline inference)
├─ Health checks & telemetry
└─ Backup (daily snapshots sent to cloud archive)

POS LOCAL (SQLite)
├─ Event log (append-only, never deleted)
├─ Offline queue (events awaiting store edge sync)
├─ Cached data (products, inventory, promotions)
└─ No backup (ephemeral, rebuilt on sync)
```

---

## The Four Schemas Deep Dive

### 1. Platform Shared Schema (Cross-Tenant)

**Location:** Cloud PostgreSQL (shared across all tenants)

**Purpose:** Metadata, subscriptions, audit, system configuration

**Tables:**
| Table | Purpose |
|---|---|
| `tenants` | Tenant ID, name, region, created_at, status |
| `subscriptions` | Tenant tier (starter/pro/enterprise), expiry, feature flags |
| `audit_log` | All system operations (immutable, append-only) |
| `api_keys` | Tenant API credentials (encrypted) |
| `webhooks` | Registered webhook endpoints for events |
| `tenant_roles` | Custom role definitions per tenant |

**Access:** Admin-only (except audit_log which is readable by ARB on request)

**Reference:** [platform_shared_DDL.sql](EnterpriseRetailAI-Docs/platform_shared_DDL.sql)

### 2. Tenant Schema (Per-Tenant)

**Location:** Cloud PostgreSQL (separate schema for each tenant)

**Purpose:** Full business data (transactions, inventory, customers, employees)

**Core Tables:**
| Table | Purpose | Volume |
|---|---|---|
| `transactions` | POS transactions | 10M–100M rows/year per store |
| `transaction_items` | Line items per transaction | 30M–300M rows/year |
| `customers` | Customer master | 100K–1M rows per tenant |
| `inventory` | Product inventory | 10K–100K SKUs |
| `employees` | Store staff | 10–1000 per store |
| `events` | Event sourcing (immutable) | All above changes logged |

**Partitioning:** By date (month) for large tables (transactions)

**Indexes:** On tenant_id, date range, customer_id, product_id (tenant-specific)

**Reference:** [tenant_schema_DDL.sql](EnterpriseRetailAI-Docs/tenant_schema_DDL.sql)

### 3. Store Edge Schema (On-Premises PostgreSQL)

**Location:** Store-local PostgreSQL (K3s pod)

**Purpose:** Sync staging, local feature store, health checks

**Tables:**
| Table | Purpose |
|---|---|
| `sync_queue` | Events from POS awaiting cloud sync |
| `feature_store` | ML features (customer value, fraud risk, demand signals) |
| `store_health` | Equipment status, connectivity, POS heartbeats |
| `local_inventory` | Cached inventory from cloud (5-min TTL) |

**Retention:** Events auto-delete after cloud ACK; health checks purged after 30 days

**Reference:** [store_edge_pg_DDL.sql](EnterpriseRetailAI-Docs/store_edge_pg_DDL.sql)

### 4. POS Local Schema (On-Device SQLite)

**Location:** POS terminal (Windows, Android)

**Purpose:** Offline resilience (append-only event log, offline queue, cache)

**Tables:**
| Table | Purpose |
|---|---|
| `events` | Append-only transaction event log (CREATE, ADD_ITEM, COMPLETE, VOID, RETURN) |
| `offline_queue` | Events awaiting sync to store edge |
| `product_cache` | Cached product master (updated daily) |
| `promotion_cache` | Cached promotions (updated daily) |
| `customer_cache` | Cached customer info (loyalty, preferences) |

**Properties:** Never delete rows, only mark as synced

**Reference:** [pos_local_sqlite_DDL.sql](EnterpriseRetailAI-Docs/pos_local_sqlite_DDL.sql)

---

## Data Flows

### Flow 1: Transaction Lifecycle

```
POS Terminal (offline-first)
├─ User scans item
├─ System checks local product cache
├─ System applies local promotions
├─ System creates TransactionCreated event → events table
├─ System creates ItemAdded event (per item)
├─ System calculates total
├─ System creates TransactionCompleted event
├─ Events logged to SQLite (never lost)
└─ Every 5 minutes: Events batched → Store Edge

Store Edge
├─ Receives batched events from POS
├─ Applies CRDT merge (if offline conflicts)
├─ Writes to sync_queue table
├─ Updates local inventory
├─ Every 1 minute: Queue → Cloud (streaming via Event Hubs)

Cloud
├─ Event Hubs triggers Azure Functions
├─ Function validates and enriches events
├─ Writes to tenant_001.events (append-only)
├─ Triggers downstream: analytics, ML training, billing
└─ Sends ACK back to Store Edge (event can be deleted)
```

**SLA:** <5 minutes POS→Store, <1 minute Store→Cloud (typical)

### Flow 2: ML Feature Store Update

```
Cloud: Model training (weekly)
├─ Query transaction events (past 2 weeks)
├─ Compute features (customer_lifetime_value, avg_transaction, fraud_score)
├─ Write features to Azure ML Feature Store

Store Edge: Real-time inference (every transaction)
├─ On-demand feature lookup (customer_id)
├─ Pull from local feature store (cached)
├─ Feed to ONNX fraud model
├─ Return score (<100ms)

POS: Offline inference
├─ Pre-computed features cached locally
├─ Run ONNX model
├─ Return score
└─ On reconnect: Fetch fresh features from Store Edge
```

---

## Multiregional & Data Residency

### Architecture

```
Azure Global (Control Plane)
├─ APIM (API Management) — available in all regions
├─ Azure AD (Authentication) — global
└─ Azure Key Vault — per region

Regional Instances (Data Plane)

EU Region (westeurope - Dublin)
├─ PostgreSQL: tenant_001–tenant_050 (EU tenants)
├─ Azure ML: EU data only
└─ Backup: EU-only geo-redundancy

US Region (eastus - Virginia)
├─ PostgreSQL: tenant_051–tenant_100 (US tenants)
├─ Azure ML: US data only
└─ Backup: US-only geo-redundancy

India Region (southindia - Bangalore)
├─ PostgreSQL: tenant_101–tenant_110 (India tenants, no export)
├─ Azure ML: India data only
└─ Backup: India-only geo-redundancy

China Region (chinaeast2 - Separate Azure Stack)
├─ PostgreSQL: tenant_111 (China tenant, isolated instance)
├─ Azure ML: PIPL-compliant (no cross-border)
└─ Backup: China-only (no export allowed)
```

### Data Residency Enforcement

**At Provisioning:**
```python
def provision_tenant(tenant_name, region):
    # Determine region based on compliance rules
    db_region = map_compliance_to_region(region)
    
    # Create schema in region-specific database
    db = connect(f"postgres://tenant-{db_region}-db.azure.com/")
    db.execute(f"CREATE SCHEMA tenant_{tenant_id}")
    
    # Store region in platform_shared (immutable)
    audit_db.execute("""
        INSERT INTO tenants (tenant_id, region)
        VALUES (?, ?)
    """, (tenant_id, db_region))
```

**At Runtime:**
```python
def query_tenant_data(tenant_id, query):
    # Lookup tenant's region
    region = audit_db.query(
        "SELECT region FROM tenants WHERE tenant_id = ?", 
        tenant_id
    )
    
    # Connect to region-specific database
    db = connect(f"postgres://tenant-{region}-db.azure.com/")
    
    # Execute query in correct region
    return db.execute(query)
```

### Backup & Recovery Strategy

| Level | Frequency | Retention | Recovery Time |
|---|---|---|---|
| **Point-in-time recovery** | Continuous (transactions logged) | 35 days | <1 hour |
| **Daily snapshot** | Daily (2 AM UTC) | 30 days | <4 hours |
| **Weekly backup** | Weekly (Sunday) | 1 year | <8 hours |
| **Cross-region replica** | Continuous | 7 days | <1 hour (failover) |

**Reference:** [LLD-013_Data_Schema_Design.md](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md)

---

## Schema Evolution (Adding New Fields)

### Scenario: Add "loyalty_member" field to customers

**Without downtime:**
```
1. Create new column (nullable):
   ALTER TABLE customers ADD COLUMN loyalty_member BOOLEAN DEFAULT FALSE;

2. Backfill data (background job):
   UPDATE customers SET loyalty_member = true 
   WHERE customer_id IN (SELECT... from loyalty_table);

3. Flip default if needed:
   ALTER TABLE customers ALTER COLUMN loyalty_member SET DEFAULT TRUE;

4. Drop constraint if field becomes required:
   ALTER TABLE customers ADD CONSTRAINT loyalty_member_not_null 
   CHECK (loyalty_member IS NOT NULL);

5. Deploy application code (already handles field)
```

**No downtime:** Queries with/without new field both work during migration

---

## Reference Map

| Question | Document |
|---|---|
| Data architecture overview? | [HLD-006_Data_Architecture.md](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md) |
| Schema-per-tenant design? | [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md) |
| Full schema design? | [LLD-013_Data_Schema_Design.md](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) |
| Multitenancy architecture? | [HLD-009_Multitenancy.md](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) |
| Event sourcing pattern? | [ADR-003_Event_Sourcing.md](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md) |
| SQL DDL files? | [*_DDL.sql](EnterpriseRetailAI-Docs/) |

---

## Tips for Agents

1. **Start with ADR-002** — Understand schema-per-tenant vs. RLS
2. **Know the four schemas** — platform_shared, tenant, store_edge, pos_local
3. **Reference the DDL** — Show actual table structures
4. **Explain data flows** — Walk through transaction lifecycle
5. **Cite multiregional strategy** — Show how regions are isolated
6. **Include backup info** — Explain recovery SLA and retention
7. **Mention CRDT** — Explain how offline conflicts are resolved

---

## When You Don't Know the Answer

If a user asks about data architecture not covered:
1. Check [HLD-006](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md) (overview)
2. Refer to [LLD-013](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) (detailed design)
3. Review relevant DDL file for table-level details
4. Note any gaps in documentation for follow-up
