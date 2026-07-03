# HLD-009 — Multitenancy Architecture
## EnterpriseRetailAI · Schema-per-Tenant Isolation, Provisioning & Data Residency

| Document ID | HLD-009 | Version | 1.0 | Status | Approved | Date | June 2026 |

---

## 1. Tenant Hierarchy

```
LEVEL 0: PLATFORM (HQ super-admin)
  └── LEVEL 1: ENTERPRISE GROUP  (e.g., "RetailCorp Global")
        └── LEVEL 2: FRANCHISEE  (e.g., "RetailCorp India Ltd.")
              ├── LEVEL 3: REGION  (e.g., "South India")
              │     └── LEVEL 4: STORE  (e.g., "Chennai Central")
              │           └── LEVEL 5: POS TERMINAL  (e.g., "POS-CHN-001-T01")
              └── LEVEL 3: REGION  (e.g., "North India")
```

---

## 2. Schema-per-Tenant Isolation

Each franchisee gets:
- Dedicated PostgreSQL schema: `tenant_{franchisee_id}`
- Dedicated DB user scoped to that schema only
- Dedicated Azure Key Vault with CMK for TDE
- Dedicated Event Hubs namespace
- Dedicated AKS namespace with NetworkPolicy isolation
- Dedicated Azure Key Vault (tenant secrets)
- Data residency enforced to franchisee's Azure region

```sql
-- Schema provisioning (automated via Terraform)
CREATE SCHEMA tenant_042 AUTHORIZATION svc_tenant_042;

-- No cross-schema visibility
REVOKE ALL ON SCHEMA public FROM svc_tenant_042;

-- Row-Level Security double-lock
ALTER TABLE tenant_042.transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY rls_tenant ON tenant_042.transactions
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Application middleware sets this on every connection:
-- SET LOCAL app.tenant_id = '...' (from validated JWT claim)
```

---

## 3. Tenant Isolation Enforcement Matrix

| Layer | Mechanism | Bypass Risk |
|---|---|---|
| Database (schema) | Separate DB user + RLS | None — DB-enforced |
| Database (network) | Private Endpoint per server | None — no public exposure |
| Application | TenantContext ORM middleware | Code review + SAST gate |
| API | APIM JWT policy; X-Tenant-ID header | APIM policy — not bypassable |
| Kubernetes | NetworkPolicy: deny cross-namespace | Cilium eBPF enforcement |
| Event Hubs | Separate namespace per tenant | RBAC scoped to namespace |
| Key Vault | Separate vault per tenant | MSI scoped to tenant namespace |
| Audit | Every query tagged with tenant_id | PgAudit → Sentinel alert |

---

## 4. Tenant Provisioning Pipeline

**Target:** Full new franchisee ready in < 4 hours (automated)

```
Trigger: HQ Admin approves franchisee onboarding in portal
    │
    ├─ Step 1: Identity (5 min)
    │    Create AAD App Registration (franchisee portal)
    │    Create service principal (AKS workload identity)
    │    Generate admin invite email + MFA enrollment
    │
    ├─ Step 2: Key Vault (5 min)
    │    Provision kv-{tenantId}-{region}
    │    Generate CMK for DB encryption
    │    Seed with DB credentials, Event Hubs keys
    │
    ├─ Step 3: Database Schema (10 min)
    │    CREATE SCHEMA tenant_{id}
    │    Apply full DDL (see LLD-013)
    │    Seed product catalogue from HQ master
    │    Configure RLS policies
    │
    ├─ Step 4: AKS Namespace (15 min)
    │    kubectl create namespace franchisee-{id}
    │    Apply NetworkPolicy (deny-all + allow-list)
    │    Apply ResourceQuota + LimitRange
    │    Flux GitOps: deploy tenant microservices
    │
    ├─ Step 5: Event Hubs (5 min)
    │    Create namespace: retail-events-{tenantId}
    │    Create topics: transactions, inventory, loyalty, payment, audit
    │    Configure consumer groups
    │    Set up Capture → ADLS Gen2 tenant partition
    │
    ├─ Step 6: APIM (5 min)
    │    Create Product: franchisee-{id}
    │    Apply tenant isolation policy
    │    Set rate limits and quota
    │    Register API subscriptions
    │
    ├─ Step 7: AI Bootstrapping (30 min)
    │    Create Azure ML workspace partition
    │    Seed with HQ baseline models (all 6 use cases)
    │    Schedule initial demand forecast run
    │    Register tenant in model registry
    │
    ├─ Step 8: Store Edge Provisioning (per store, parallel)
    │    Register device in IoT Hub
    │    Push IoT Edge deployment manifest
    │    Transfer initial model bundles
    │    Generate POS enrollment tokens
    │
    └─ Step 9: Verification (15 min)
         Run smoke tests (transaction flow, sync, AI scoring)
         Generate provisioning report
         Notify franchisee admin: "Platform ready"
```

---

## 5. Tenant Configuration Model

| Config Category | Set By | Franchisee Override | Validation |
|---|---|---|---|
| Encryption keys | HQ Platform | ❌ Never | Key Vault policy |
| Compliance controls | HQ Legal/CISO | ❌ Never | Azure Policy |
| AI model baseline | HQ AI Team | ✅ Fine-tune only | ARB approval |
| Pricing rules master | HQ Merchandising | ✅ Regional offsets | Bounds check |
| Promotions templates | HQ Marketing | ✅ Local promos | Category allow-list |
| Product catalogue | HQ (master) | ✅ Add local SKUs | Barcode dedup check |
| Staff management | Franchisee | ✅ Full | — |
| Store configuration | Franchisee | ✅ Full | Schema validation |
| POS terminal config | Store Manager | ✅ Limited | Allowed-fields only |
| Data residency region | HQ Legal | ❌ Never | Azure Policy deny |

---

## 6. Data Residency Enforcement

```
Azure Policy: "Allowed locations" assigned at franchisee subscription/RG level

India franchisee subscription:
  allowedLocations: ["centralindia", "southindia"]
  Effect: Deny — any resource creation outside these regions blocked

EU franchisee subscription:
  allowedLocations: ["germanywestcentral", "francecentral", "northeurope"]

China franchisee subscription:
  allowedLocations: ["chinaeast2", "chinanorth2"]
  Additional: Azure China (21Vianet) separate sovereign cloud deployment

Cross-border data transfer controls:
  EU → non-EU: SCCs auto-attached to DPA template
  India: DPA required before any personal data export
  China: PIPL adequacy assessment required; data stays in China region
```

---

## 7. Tenant Offboarding

```
Trigger: Franchisee agreement ends / termination
    │
    ├─ Data Export (30 days notice period)
    │    Generate full data export (transactions, customers, loyalty)
    │    Encrypted archive in ADLS → franchisee download (30-day link)
    │
    ├─ PII Erasure (if no legal hold)
    │    Run erasure pipeline for all customer PII
    │    Retain financial records (7 years) — non-PII only
    │
    ├─ Infrastructure Decommission (day 31)
    │    Delete AKS namespace + all workloads
    │    Drop DB schema (after export confirmed)
    │    Delete Event Hubs namespace
    │    Delete Key Vault (soft-delete → 90-day purge protection)
    │    Deregister store edge devices from IoT Hub
    │    Revoke all AAD app registrations
    │
    └─ Audit Record
         Immutable offboarding log retained 7 years
```

---

## 8. Related Documents

| Document | Reference |
|---|---|
| Tenant Provisioning LLD | `02_LLD/LLD-010_Tenant_Provisioning_Service.md` |
| Data Schema LLD | `02_LLD/LLD-013_Data_Schema_Design.md` |
| Data Architecture HLD | `01_HLD/HLD-006_Data_Architecture.md` |
| Security HLD | `01_HLD/HLD-007_Security_Compliance.md` |
