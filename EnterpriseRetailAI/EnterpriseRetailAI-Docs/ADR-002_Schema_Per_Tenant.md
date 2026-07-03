# ADR-002 — Schema-per-Tenant Isolation Model
## EnterpriseRetailAI · Architecture Decision Record

| ID | ADR-002 | Status | Approved |

---

## Context

With 10,000+ potential franchisee tenants, the platform must provide strong data isolation. Three data isolation models were evaluated against requirements: regulatory compliance (GDPR, DPDP, PIPL), operational simplicity, cost, and performance.

---

## Options Considered

### Option A: Silo (separate DB per tenant)
- Maximum isolation; simplest security model
- Cost: prohibitive at 10,000 tenants (10,000 × DB instance cost)
- Management: impractical — 10,000 independent DB servers to patch/upgrade

### Option B: Schema-per-Tenant (shared server, isolated schema) ✅ (Selected)
- Strong isolation: separate schema, separate DB user, separate CMK
- Cost: 100 tenants per DB server = 100× more efficient than silo
- Row-level security as double-lock
- Regulatory: per-schema encryption with customer-managed keys

### Option C: Row-level isolation (shared schema, shared tables)
- All tenants in same tables with tenant_id column
- Lowest cost, easiest operations
- Risk: single misconfigured query can expose all tenant data
- Not acceptable for PCI-DSS and GDPR audit requirements

---

## Decision

**Schema-per-Tenant** (Option B) is adopted.

Implementation:
- Schema name: `tenant_{franchisee_id}`
- Separate DB user scoped to that schema only
- CMK per tenant in Azure Key Vault (TDE encryption)
- Row-Level Security as defence-in-depth (not primary control)
- Max 100 schemas per Azure SQL/PostgreSQL Flexible server

---

## Consequences

**Positive:**
- Strong isolation satisfies all regulatory auditors (PCI, GDPR, DPDP, PIPL)
- Simple audit query: show all access for tenant X
- No application-level bug can cross tenant boundaries at DB layer

**Negative:**
- Schema provisioning adds ~10 minutes to tenant onboarding (automated)
- Cross-tenant analytics require secure data extract + anonymisation pipeline
- PostgreSQL max schemas ~10,000 per server — adequate for target scale

**Review Trigger:** If tenant count exceeds 5,000 per region, evaluate shard-per-N-tenants model.

