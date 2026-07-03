# SKILL.md — Multitenancy & Data Isolation Architecture

**Skill Name:** multitenancy-isolation

**Purpose:** Help AI agents navigate tenant isolation patterns, provisioning workflows, schema design, and GDPR/compliance implications across the multitenancy architecture.

---

## When to Use This Skill

Use this skill when:
- **Tenant isolation questions** — "How do we ensure tenant A can't see tenant B's data?"
- **Provisioning workflows** — "What happens when a new franchisee signs up?"
- **Schema customization** — "Can tenants have custom fields? How is schema evolution managed?"
- **Data residency** — "Can we keep EU customer data in Europe and US data in US?"
- **Compliance** — "How do we implement GDPR data deletion? Data export?"
- **Multi-geography** — "How do we handle cross-region tenant deployments?"
- **Performance at scale** — "How do we manage queries across hundreds of tenant schemas?"

Do NOT use this skill for:
- General database architecture (use [HLD-006](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md) directly)
- Code-level implementation
- SQL query optimization

---

## Core Pattern: Schema-Per-Tenant Isolation

The EnterpriseRetailAI uses **schema-per-tenant** multitenancy, NOT row-level security (RLS) alone.

**Key Difference:**
- ❌ **RLS (Row-Level Security):** Single schema, all tenants' data in same tables, filtered by tenant_id
- ✅ **Schema-per-Tenant:** Separate PostgreSQL schema per tenant, full logical isolation

**Why Schema-per-Tenant?** See [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md)
- GDPR compliance (data deletion is schema DROP)
- Tenant customization (custom fields per schema)
- Performance isolation (each schema has own indexes, statistics)
- Multi-geography support (schema can be in different regions)

**Reference:** [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [HLD-009_Multitenancy.md](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md)

---

## Tenant Hierarchy & Organization

Tenants are organized in a hierarchy:

```
Enterprise (HQ Corporate)
├── Tenant 1: Europe
│   ├── Store: London
│   ├── Store: Paris
│   └── Store: Berlin
├── Tenant 2: North America
│   ├── Store: New York
│   ├── Store: Toronto
│   └── Store: Los Angeles
└── Tenant 3: APAC
    ├── Store: Sydney
    ├── Store: Tokyo
    └── Store: Singapore
```

**Key Concepts:**
- **Tenant:** Franchise or geographic region (e.g., "Europe Franchise")
- **Store:** Physical retail location (POS terminals)
- **User:** Employee assigned to store(s)

**Reference:** [HLD-009_Multitenancy.md](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md)

---

## Schema Structure

Each tenant has:

### 1. **Tenant Schema (per-tenant)**
Location: `tenant_<id>` in PostgreSQL
Contents:
- Transaction tables (transactions, transaction_items, voids, returns)
- Inventory tables (products, stock, replenishment)
- Customer tables (customers, loyalty, preferences)
- Employee tables (employees, shifts, permissions)
- Event log tables (all events for offline sync)

**Reference:** [tenant_schema_DDL.sql](EnterpriseRetailAI-Docs/tenant_schema_DDL.sql)

### 2. **Platform Shared Schema (cross-tenant)**
Location: `platform_shared` in PostgreSQL
Contents:
- Tenant metadata (tenant_id, name, region, created_at)
- Subscription & billing (tenant tier, expiry, feature flags)
- Audit log (who provisioned, deleted, exported data)
- System configuration (feature toggles, API rate limits)

**Reference:** [platform_shared_DDL.sql](EnterpriseRetailAI-Docs/platform_shared_DDL.sql)

### 3. **POS Local Schema (on-device)**
Location: SQLite on POS terminal
Contents:
- Offline event log (transactions while disconnected)
- Offline queue (events awaiting sync to store edge)
- Cached data (inventory, promotions, customer info)

**Reference:** [pos_local_sqlite_DDL.sql](EnterpriseRetailAI-Docs/pos_local_sqlite_DDL.sql)

### 4. **Store Edge Schema (on-premises)**
Location: PostgreSQL at store edge
Contents:
- Sync staging tables (events from POS, awaiting cloud sync)
- Local feature store (cached ML features for offline inference)
- Health checks (store equipment status, connectivity)

**Reference:** [store_edge_pg_DDL.sql](EnterpriseRetailAI-Docs/store_edge_pg_DDL.sql)

---

## Workflow: Tenant Provisioning

### Step 1: Identify the Provisioning Trigger
- **New Franchisee Signup** → Full tenant provisioning
- **New Store in Existing Tenant** → Store provisioning (reuse tenant schema)
- **New User in Store** → User provisioning (add to tenant's employee table)

### Step 2: Locate the Provisioning Service
Read [LLD-010_Tenant_Provisioning_Service.md](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md)

**Service responsibilities:**
- Validate tenant request (legal review, geo restrictions, compliance)
- Create tenant schema (run tenant_schema_DDL.sql with tenant_id)
- Provision resources (PostgreSQL users, Blob Storage containers, Azure Key Vault secrets)
- Bootstrap data (default products, tax rules, payment methods)
- Enroll in MLOps (create feature store schema)
- Configure API rate limits (in platform_shared schema)

### Step 3: Infrastructure as Code
Provisioning uses **Terraform modules**:
- `modules/tenant-schema/` — Creates PostgreSQL schema
- `modules/tenant-storage/` — Creates Blob Storage container for tenant data
- `modules/tenant-keyvault/` — Creates Key Vault for secrets (API keys, DB passwords)
- `modules/tenant-feature-store/` — Sets up ML feature store schema

**State Management:** Terraform state stored in Azure Blob Storage with resource-level locking

**Reference:** [LLD-010_Tenant_Provisioning_Service.md](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md)

### Step 4: Data Residency Configuration
Specify where tenant data lives:
- **EU Tenant:** Data in `westeurope` region (Dublin, Ireland)
- **US Tenant:** Data in `eastus` (Virginia) or `westus` (California)
- **APAC Tenant:** Data in `southeastasia` (Singapore) or `australiaeast` (Sydney)

Enforced at:
- PostgreSQL instance location
- Blob Storage replication
- Event Hubs partition placement
- Azure ML compute location

**Compliance:** GDPR (EU), CCPA (US), DPDP (India), PIPL (China)

**Reference:** [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)

### Step 5: Schema Bootstrap
Each new schema gets:
```sql
-- Seed data (from tenant bootstrap)
INSERT INTO tenant_<id>.products 
  SELECT * FROM platform_shared.default_products;

INSERT INTO tenant_<id>.tax_rules 
  SELECT * FROM platform_shared.tax_rules_by_country 
  WHERE country_code = '<tenant_country>';

INSERT INTO tenant_<id>.payment_methods 
  FROM platform_shared.payment_methods_by_region 
  WHERE region = '<tenant_region>';
```

---

## Example: GDPR Data Deletion Request

**User Question:** "How do we handle a GDPR right-to-be-forgotten request?"

**Step 1:** Access [LLD-010_Tenant_Provisioning_Service.md](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md) (data handling) + [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md) (compliance)

**Step 2:** Understand the request flow
1. Customer (EU) submits GDPR right-to-be-forgotten request
2. Tenant admin submits request to platform (via Tenant Admin API)
3. Provisioning service logs request in audit table (platform_shared.audit_log)
4. Data deletion job is queued

**Step 3:** Deletion Process
```
Identify all data owned by customer in tenant schema:
  - Transactions (transaction_id)
  - Loyalty records (customer_id)
  - Preferences (customer_id)
  - PII (name, email, phone)

Delete in order:
  1. PII fields (name, email, phone) → anonymize
  2. Customer records → cascade delete
  3. Transactions → retention check (anti-fraud: keep 7 years per PCI)
     Problem: GDPR says forget, PCI says keep
     Resolution: Anonymize PII, keep transaction for compliance

Verify:
  - Re-run customer query → no PII found
  - Audit log records deletion (timestamp, reason, by whom)
```

**Step 4:** Key Challenge: Offline Data
- POS terminals have cached customer data (offline cache)
- Store edge has synced transactions
- **Solution:** Cascade deletion marks affected records as "do not sync"; offline cache cleared next sync

**Answer:**
> GDPR deletion follows this process:
>
> 1. **Request Validation:** Customer submits deletion request; platform logs it in audit table
> 2. **Anonymization:** Personal data (name, email, phone) is deleted from `customer` table
> 3. **Transaction Handling:** Transactions are kept for PCI-DSS (7-year retention), but PII is removed
> 4. **Cascade:** All related records (loyalty, preferences, payment tokens) are deleted
> 5. **Sync Cleanup:** Deletion is marked for offline systems; next sync clears cached data
> 6. **Verification:** Re-query confirms customer is unfindable by PII
> 7. **Audit:** Deletion logged (who approved, timestamp, reason)
>
> **Timeline:** 24 hours from request to completion
> **Compliance:** GDPR + local data protection laws
>
> See [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md), [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md), [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md).

---

## Isolation Guarantees

### 1. **Logical Isolation**
- Each tenant is a separate PostgreSQL schema
- Queries on `tenant_1` schema cannot access `tenant_2` tables
- No row-level filtering mistakes possible

### 2. **Authentication Isolation**
- Each tenant gets unique PostgreSQL role (user)
- Role has `GRANT` on only their schema
- Credentials stored in Azure Key Vault per tenant

### 3. **Network Isolation**
- Database subnet is private (no internet access)
- Access only via application tier (API layer)
- API gateway enforces tenant_id in JWT token

### 4. **Encryption Isolation**
- Each schema encrypted with tenant-specific key
- Key stored in Azure Key Vault
- Transparent Data Encryption (TDE) at column level for PII

**Reference:** [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)

---

## Common Multitenancy Scenarios

| Scenario | Solution | Reference |
|---|---|---|
| **New Franchisee Onboards** | Run Terraform modules, seed data, create users | [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md) |
| **Franchisee Wants Custom Fields** | Add columns to tenant schema, no impact on others | [LLD-013](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) |
| **Franchisee Expands to New Region** | Create new tenant schema in target region, reuse products/config | [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) |
| **GDPR Data Deletion** | Anonymize PII, cascade delete, mark for offline sync | [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md) |
| **Data Export (GDPR)** | Query tenant schema, export to CSV/JSON, encrypt, sign | [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md) |
| **Tenant Deactivation** | Backup schema, disable API access, archive data | [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) |
| **Cross-Tenant Reporting (HQ)** | Query platform_shared tables (tenant aggregates only) | [HLD-006](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md) |
| **Performance Optimization** | Add indexes per tenant schema, no contention | [LLD-013](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) |

---

## Reference Map

| Question | Document |
|---|---|
| Why schema-per-tenant vs. RLS? | [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md) |
| What's the tenant structure? | [HLD-009_Multitenancy.md](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) |
| How do we provision tenants? | [LLD-010_Tenant_Provisioning_Service.md](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md) |
| What's the schema design? | [LLD-013_Data_Schema_Design.md](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) |
| What are the actual DDL files? | [tenant_schema_DDL.sql](EnterpriseRetailAI-Docs/tenant_schema_DDL.sql), [platform_shared_DDL.sql](EnterpriseRetailAI-Docs/platform_shared_DDL.sql) |
| How do we ensure compliance? | [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md) |
| What's the data architecture? | [HLD-006_Data_Architecture.md](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md) |

---

## Tips for Agents

1. **Start with ADR-002** — Understand why schema-per-tenant was chosen
2. **Reference the hierarchy** — Explain Enterprise → Tenant → Store → User relationships
3. **Mention the three schemas** — Tenant schema + Platform shared schema + POS local schema
4. **Highlight isolation** — Explain logical, authentication, network, and encryption isolation
5. **Connect to provisioning** — Mention Terraform modules for infrastructure-as-code
6. **Cite compliance** — Reference GDPR, CCPA, DPDP, PIPL requirements
7. **Show data residency** — Explain regional placement for compliance

---

## When You Don't Know the Answer

If a user asks about multitenancy not covered by these docs:
1. Check if the question belongs to general data architecture (use [HLD-006](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md))
2. If a tenancy concern exists but is missing, note this as a gap
3. Point to the nearest analogous scenario (e.g., "Custom fields work like custom schemas")
