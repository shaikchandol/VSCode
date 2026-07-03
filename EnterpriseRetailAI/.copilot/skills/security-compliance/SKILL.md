# SKILL.md — Security, Compliance & Zero Trust Architecture

**Skill Name:** security-compliance

**Purpose:** Help AI agents understand security controls, compliance requirements (GDPR, CCPA, DPDP, PIPL, PCI-DSS), zero trust architecture, and security-by-design patterns.

---

## When to Use This Skill

Use this skill when:
- **Compliance questions** — "How do we meet GDPR requirements? What about CCPA/DPDP/PIPL?"
- **Security architecture** — "How is our zero trust model implemented?"
- **Data protection** — "How is PII encrypted? What's the key management strategy?"
- **Audit & governance** — "How do we maintain audit trails for compliance?"
- **Payment security** — "How is PCI-DSS compliance enforced?"
- **Secret management** — "How are API keys and credentials stored?"
- **Access control** — "What are the authentication and authorization mechanisms?"

Do NOT use this skill for:
- Network infrastructure specifics (use [HLD-004](EnterpriseRetailAI-Docs/HLD-004_Cloud_Platform_Azure.md))
- Code-level security implementation
- General IT security policies (use organizational docs)

---

## Compliance Framework

EnterpriseRetailAI operates under multiple regulatory regimes:

| Regulation | Jurisdiction | Requirement | Implementation |
|---|---|---|---|
| **GDPR** | EU | Data protection, deletion, portability | Schema-per-tenant (ADR-002), data export API, 30-day deletion SLA |
| **CCPA** | California, USA | Consumer privacy rights, opt-out | Data export, deletion (same as GDPR), no sale of PII |
| **DPDP** | India | Data residency, consent | Regional schema placement (westindia), explicit consent tracking |
| **PIPL** | China | Data residency, restricted transfer | Data must stay in China (no export allowed) |
| **PCI-DSS** | Global (payment) | Card data protection | P2PE tokenisation (ADR-007), zero card storage in POS |

**Reference:** [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)

---

## Zero Trust Architecture

### Core Principle: "Never Trust, Always Verify"

```
Traditional: Trust internal network, verify external
   Network boundary → Inside = safe, Outside = risky

Zero Trust: Verify everything
   Every request, every device, every user → Authenticate + Authorize
```

### Implementation in EnterpriseRetailAI

**1. Authentication**
- OAuth 2.0 for cloud APIs (Azure AD)
- mTLS (mutual TLS) for POS ↔ Store Edge (certificate pinning)
- JWT tokens signed with RS256 (asymmetric)
- API keys rotated quarterly

**2. Authorization**
- Role-Based Access Control (RBAC)
  - POS terminals: Limited to transaction endpoints
  - Store managers: Transaction + reporting endpoints
  - Franchisee admins: Tenant configuration endpoints
  - Cloud admins: Full access
- Least privilege principle (minimal permissions by default)

**3. Encryption**
- **Data in transit:** TLS 1.3 (all inter-tier communication)
- **Data at rest:** AES-256 (database encryption, file storage)
- **Encryption keys:** Azure Key Vault (centralized, rotated auto)

**4. Network Isolation**
- POS ↔ Store Edge: Private network (no internet)
- Store Edge ↔ Cloud: HTTPS + VPN / ExpressRoute
- Database: Private subnet (no direct internet access)

**5. Audit & Monitoring**
- All API calls logged (who, what, when, from where)
- Sensitive operations flagged (delete, admin config)
- Real-time alerts for anomalies (unusual access patterns)
- Immutable audit log (append-only, never deleted)

**Reference:** [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)

---

## GDPR Compliance Deep Dive

### What is GDPR?
**General Data Protection Regulation** — EU law protecting personal data (name, email, phone, purchase history, IP address).

### Key Requirements

| Requirement | Implementation |
|---|---|
| **1. Lawful Basis** | Consent tracking: customer must opt-in for marketing, personalization |
| **2. Data Minimization** | Collect only necessary data (no "just in case" fields) |
| **3. Purpose Limitation** | Use data only for stated purpose (e.g., transaction, not resale) |
| **4. Storage Limitation** | Delete data after purpose served (e.g., transactions after 7 years per PCI) |
| **5. Integrity & Confidentiality** | Encryption, access controls, backup security |
| **6. Accountability** | Document all processing, maintain audit trail |
| **7. Data Subject Rights** — **Critical** | Users have 5 rights: |
| — Access | "Show me all my data" → Data export within 30 days |
| — Rectification | "Fix my data" → Update API + notification |
| — Deletion (RTbF) | "Forget me" → Anonymize/delete within 30 days |
| — Restriction | "Don't process my data" → Flag for no-process |
| — Portability | "Give me my data" → Export in standard format (CSV/JSON) |

### How We Implement GDPR

**1. Schema-Per-Tenant Isolation (ADR-002)**
- Each tenant = separate PostgreSQL schema
- EU tenant → westeurope region (Dublin)
- GDPR deletion = DROP SCHEMA (atomic, fast)

**2. Data Export API**
```
POST /api/v1/tenant/{tenant_id}/gdpr/export
└─ Fetches all customer data (PII, transactions, preferences)
└─ Encrypts + signs export file
└─ Returns URL to download (expires in 24h)
└─ Audit log records: who exported, when, reason
```

**3. Data Deletion API**
```
POST /api/v1/tenant/{tenant_id}/gdpr/delete/{customer_id}
└─ Flags customer for deletion in audit table
└─ Anonymizes PII (name, email, phone, address)
└─ Cascades to all related records (loyalty, preferences)
└─ Keeps transactions for PCI (anonymized)
└─ Sync to offline systems (POS, Store Edge clear on next sync)
└─ SLA: 30 days completion, 24 hours typical
```

**4. Audit Trail**
```
All GDPR operations logged:
├─ Data export: who, when, customer IDs, reason
├─ Data deletion: who, when, customer IDs, approval status
├─ Consent changes: customer, field, timestamp
└─ Immutable log (append-only, signatures validated)
```

**Reference:** [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md), [LLD-010_Tenant_Provisioning_Service.md](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md)

---

## CCPA Compliance

### What is CCPA?
**California Consumer Privacy Act** — Similar to GDPR but focuses on consumer rights + prohibition on "sale" of data.

### Key Differences from GDPR

| Aspect | GDPR | CCPA |
|---|---|---|
| **Scope** | Personal data of EU residents | Personal data of California residents |
| **Definition** | Broad (includes pseudo-anonymized) | Broad (includes inferred data) |
| **"Sale"** | No concept | Prohibited (unless opt-out) |
| **Rights** | 6 (access, rectify, delete, restrict, portability, not profiled) | 4 (access, delete, opt-out, no discrimination) |
| **Fines** | Up to €20M or 4% revenue | Up to $2,500–$7,500 per violation |

### Implementation

- Same data export/deletion APIs as GDPR
- Add **CCPA "Do Not Sell" flag** per customer (read from CRM)
- Ensure no personalization/targeting if flag set
- Stricter data retention (delete sooner than GDPR allows)

**Reference:** [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)

---

## PCI-DSS Compliance (Payment Security)

### What is PCI-DSS?
**Payment Card Industry Data Security Standard** — Requirement for systems processing card payments.

### Core Principle
**POS terminal must NEVER see, store, or transmit raw card data.**

### How We Comply

**1. P2PE Tokenisation (ADR-007)**
```
Customer swipes card
    ↓
P2PE device (hardware) encrypts card data
    ↓
Card data goes directly to payment gateway (bypasses POS)
    ↓
Gateway returns token (e.g., "TOK-ABC123")
    ↓
POS stores only token (not card)
    ↓
For charges: POS sends token to gateway (not card)
```

**2. What POS Never Sees**
- ❌ Card number (PAN)
- ❌ CVC (3-digit security code)
- ❌ Expiration date (in clear)
- ✅ Only: Token (meaningless without gateway key)

**3. Storage & Transmission**
- Tokens encrypted with AES-256
- Token vault in Azure Key Vault (HSM-backed)
- Offline queue uses encrypted local SQLite
- On reconnect, tokens re-transmitted securely

**Reference:** [ADR-007_P2PE_Payment.md](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md), [LLD-012_Payment_Service.md](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md)

---

## Audit & Accountability

### Immutable Audit Log

Every action is logged in append-only table:
```sql
audit_log (
  id UUID,
  timestamp TIMESTAMP,
  actor (user_id, role),
  action (read, write, delete, export, config_change),
  resource (customer, transaction, config),
  result (success, failure),
  ip_address,
  user_agent,
  signature (HMAC for integrity)
)
```

**Properties:**
- Append-only (no updates, no deletes)
- Signed (HMAC-SHA256 to detect tampering)
- Timestamped (with timezone)
- Immutable on cloud (Azure Immutable Blob Storage)

### Retention Policy
- **Operational logs:** 90 days (local, searchable)
- **Audit logs:** 7 years (archival, legal hold)
- **Transaction logs:** Per PCI (7 years)

---

## Common Compliance Scenarios

| Scenario | Implementation | Timeline |
|---|---|---|
| **EU Customer requests data export** | Query tenant schema, encrypt, sign, return file | 5 minutes (SLA: 30 days) |
| **EU Customer requests deletion** | Anonymize PII, cascade delete, flag for audit | 1 hour (SLA: 30 days) |
| **Payment audit triggered** | Pull immutable audit log, verify P2PE, show token path | On-demand |
| **New DPDP requirement (India)** | Provision new tenant schema in India region | 1 day (provisioning) |
| **PIPL update (China)** | Ensure China tenant data stays in-region, no export | Ongoing monitoring |
| **Security breach detected** | Alert, isolate, preserve audit logs, notify customers | <1 hour response |

---

## Reference Map

| Question | Document |
|---|---|
| Full security & compliance architecture? | [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md) |
| GDPR implementation details? | [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md) |
| PCI-DSS payment security? | [ADR-007_P2PE_Payment.md](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md) |
| Tenant provisioning for compliance? | [LLD-010_Tenant_Provisioning_Service.md](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md) |
| Payment processing? | [LLD-012_Payment_Service.md](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md) |
| API security standards? | [LLD-014_API_Design.md](EnterpriseRetailAI-Docs/LLD-014_API_Design.md) |

---

## Tips for Agents

1. **Identify the regulation** — GDPR (EU), CCPA (US), DPDP (India), PIPL (China), PCI-DSS (payment)
2. **Know the requirement** — Data export, deletion, residency, encryption, audit
3. **Reference the implementation** — Schema-per-tenant, P2PE, audit log, API endpoints
4. **Cite the ADR** — Explain why this design was chosen (trade-offs, benefits)
5. **Include timelines** — Typical execution time vs. SLA requirements
6. **Show the flow** — Walk through a scenario (GDPR deletion, payment processing)

---

## When You Don't Know the Answer

If a user asks about compliance requirements not covered:
1. Check [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md) (overview)
2. If a specific regulation is missing, note as a gap (add to architecture)
3. Point to nearest analogous requirement (e.g., "DPDP works like GDPR for India")
4. Recommend consulting Legal/Compliance team for non-architectural questions
