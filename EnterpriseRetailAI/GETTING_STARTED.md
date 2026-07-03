# Getting Started with EnterpriseRetailAI Architecture

**Last Updated:** July 2026 | **Time to Read:** 5 minutes

Welcome! This guide will help you understand the EnterpriseRetailAI documentation structure and start contributing or asking questions.

---

## 🎯 Quick Start (Choose Your Path)

### Path 1: "I want a 1-minute overview"
→ Read [QUICK_REFERENCE.md](QUICK_REFERENCE.md) (system diagram, 8 key decisions, 6 AI models, APIs, SLAs)

### Path 2: "I'm a developer joining the team"
→ Start here:
1. Read this page (5 min)
2. Read [QUICK_REFERENCE.md](QUICK_REFERENCE.md) (5 min)
3. Choose your area: [POS/Transaction](EnterpriseRetailAI-Docs/HLD-002_POS_Application.md) | [Store Edge](EnterpriseRetailAI-Docs/HLD-003_Store_Edge_Platform.md) | [Cloud](EnterpriseRetailAI-Docs/HLD-004_Cloud_Platform_Azure.md) | [AI/ML](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) | [Data](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md)
4. Drill into relevant LLDs for implementation details

### Path 3: "I need to answer an architecture question"
→ Use [AGENTS.md](AGENTS.md) to find the right document by question type

### Path 4: "I'm an AI agent (Copilot, Claude, etc.)"
→ Read [.github/copilot-instructions.md](.github/copilot-instructions.md) for context, then use skills:
- [mlops-drift-analysis](.copilot/skills/mlops-drift-analysis/SKILL.md) — Model training, retraining, monitoring
- [multitenancy-isolation](.copilot/skills/multitenancy-isolation/SKILL.md) — Tenant isolation, provisioning, GDPR
- [offline-first-architecture](.copilot/skills/offline-first-architecture/SKILL.md) — Offline resilience, sync, CRDT
- [integration-architecture](.copilot/skills/integration-architecture/SKILL.md) — External systems, APIs, events
- [security-compliance](.copilot/skills/security-compliance/SKILL.md) — GDPR, PCI-DSS, zero trust, audit
- [data-architecture](.copilot/skills/data-architecture/SKILL.md) — Schema design, multiregional, backup
- [performance-scaling](.copilot/skills/performance-scaling/SKILL.md) — system performance, scaling, capacity planning
- [DOCUMENT_MANIFEST.md](DOCUMENT_MANIFEST.md) — repository manifest for documentation standards and validation tools

---

## 🏗️ The System in 30 Seconds

```
┌─────────────────────────────┐
│      CLOUD (Azure)          │
│  AKS, Event Hubs, ML, SQL   │ ← Training, analytics, APIs
└──────────────┬──────────────┘
               │ Streaming (Event Hubs)
┌──────────────▼──────────────┐
│     STORE EDGE (K3s)        │
│  PostgreSQL, IoT Edge, ML   │ ← Local sync, batch, reporting
└──────────────┬──────────────┘
               │ Batch (every 5 min)
┌──────────────▼──────────────┐
│   POS TERMINAL (Device)     │
│  Windows .NET / Android     │ ← Transactions, local ML
└─────────────────────────────┘

Key Property: Offline-first
├─ POS: Works indefinitely offline (append-only event log)
├─ Store: Works weeks offline (PostgreSQL queue)
└─ Cloud: Receives synced events → CRDT resolves conflicts
```

---

## 📚 Document Hierarchy

```
TOGAF 10 ADM Framework
├─ TOGAF Document (full enterprise architecture)
│
├─ HIGH-LEVEL DESIGNS (HLD-001 through HLD-010)
│  ├─ HLD-001: System overview (start here)
│  ├─ HLD-002: POS application
│  ├─ HLD-003: Store edge platform
│  ├─ HLD-004: Cloud platform (Azure)
│  ├─ HLD-005: AI/ML platform (6 use cases)
│  ├─ HLD-006: Data architecture (schemas, event sourcing)
│  ├─ HLD-007: Security & compliance
│  ├─ HLD-008: Integration (external systems)
│  ├─ HLD-009: Multitenancy (schema-per-tenant)
│  └─ HLD-010: Offline architecture (sync, CRDT)
│
├─ LOW-LEVEL DESIGNS (LLD-001 through LLD-015)
│  ├─ LLD-001: Transaction engine (state machine)
│  ├─ LLD-002: Offline sync agent (event queuing)
│  ├─ LLD-003: Store edge orchestration (K3s)
│  ├─ LLD-004–009: Six AI use cases (fraud, forecast, promo, CV, NLP, maintenance)
│  ├─ LLD-010: Tenant provisioning (onboarding)
│  ├─ LLD-011: CRDT sync engine (conflict resolution)
│  ├─ LLD-012: Payment service (P2PE, offline queue)
│  ├─ LLD-013: Data schema design (full DDL)
│  ├─ LLD-014: API design (standards, patterns)
│  └─ LLD-015: MLOps pipeline (training, retraining)
│
├─ ARCHITECTURE DECISION RECORDS (ADR-001 through ADR-008)
│  ├─ ADR-001: Azure cloud platform
│  ├─ ADR-002: Schema-per-tenant isolation ⭐ Key for multitenancy
│  ├─ ADR-003: Event sourcing ⭐ Key for transactions
│  ├─ ADR-004: K3s for store edge
│  ├─ ADR-005: ONNX for POS AI ⭐ Key for edge inference
│  ├─ ADR-006: CRDT conflict resolution ⭐ Key for offline
│  ├─ ADR-007: P2PE payment
│  └─ ADR-008: Azure OpenAI NLP
│
├─ API SPECIFICATIONS (*_API_Spec.md)
│  ├─ POS_API_Spec.md (terminal transactions, inventory)
│  ├─ Store_Management_API_Spec.md (reporting, operations)
│  ├─ Tenant_Admin_API_Spec.md (provisioning, config)
│  └─ AI_Inference_API_Spec.md (model scoring)
│
└─ DATABASE SCHEMAS (*_DDL.sql)
   ├─ tenant_schema_DDL.sql (per-tenant PostgreSQL)
   ├─ platform_shared_DDL.sql (cross-tenant metadata)
   ├─ pos_local_sqlite_DDL.sql (on-device append-only log)
   └─ store_edge_pg_DDL.sql (on-premises sync staging)
```

---

## 🔑 The 8 Key Decisions (ADRs)

These architectural decisions shape everything:

| Decision | Why | Reference |
|---|---|---|
| **1. Azure Cloud** | Cost, ecosystem, ML capabilities | [ADR-001](EnterpriseRetailAI-Docs/ADR-001_Azure_Cloud_Platform.md) |
| **2. Schema-Per-Tenant** | GDPR compliance, isolation, customization | [ADR-002](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md) |
| **3. Event Sourcing** | Audit trail, offline recovery, replay | [ADR-003](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md) |
| **4. K3s Store Edge** | Edge-first, lightweight, low-cost | [ADR-004](EnterpriseRetailAI-Docs/ADR-004_K3s_Store_Edge.md) |
| **5. ONNX for POS AI** | Portable, fast (<100ms), offline | [ADR-005](EnterpriseRetailAI-Docs/ADR-005_ONNX_POS_Inference.md) |
| **6. CRDT Conflict Resolution** | Automatic merge, no manual resolution | [ADR-006](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md) |
| **7. P2PE Payments** | PCI-DSS compliance, zero card storage | [ADR-007](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md) |
| **8. Azure OpenAI + RAG** | Accuracy, transparency, cost-effective | [ADR-008](EnterpriseRetailAI-Docs/ADR-008_Azure_OpenAI_NLP.md) |

**Pro Tip:** To understand "Why?" any architectural choice, go to the ADR. It explains context, decision, and consequences.

---

## 🚀 Common Tasks

### "I'm adding a new AI use case"
**Steps:**
1. Review [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) (AI/ML platform architecture)
2. Use template [new-lld-template.prompt.md](.copilot/prompts/new-lld-template.prompt.md) to document your model
3. Add to [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) with performance metrics
4. Update [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md) with training pipeline
5. Update [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md) with thresholds

**References:** [LLD-004–009](EnterpriseRetailAI-Docs/), [LLD-015](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md)

### "I'm onboarding a new tenant (franchisee)"
**Steps:**
1. Read [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) (multitenancy model)
2. Read [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md) (provisioning service)
3. Check [tenant_schema_DDL.sql](EnterpriseRetailAI-Docs/tenant_schema_DDL.sql) (schema template)
4. Use Terraform modules to provision (infrastructure-as-code)
5. Verify compliance: GDPR (EU), CCPA (US), DPDP (India), PIPL (China)

**Key Concept:** Each tenant gets isolated PostgreSQL schema → GDPR deletion = DROP SCHEMA

### "A store went offline for 3 days"
**What happens:**
1. POS terminals log all events locally (SQLite append-only log) → **zero data loss** ✅
2. On reconnect, POS syncs to Store Edge (batch pulls, ~10 min)
3. CRDT automatically resolves any concurrent offline edits
4. Store Edge syncs to Cloud (streaming via Event Hubs, ~30 min)
5. All systems eventually consistent

**Read:** [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md), [LLD-011](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md)

### "I need to integrate with an external system (SAP, Salesforce, etc.)"
**Steps:**
1. Review [HLD-008](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md) (integration patterns)
2. Check [LLD-014](EnterpriseRetailAI-Docs/LLD-014_API_Design.md) (API design standards)
3. Choose pattern:
   - REST (sync, request-response)
   - gRPC (streaming, high-performance)
   - Event Hubs (async pub-sub)
   - Offline queue (retry with guarantee)
4. Implement with proper auth: OAuth 2.0, mTLS, API key, or JWT
5. Add offline handling (caching, queuing)

**Examples:** [POS_API_Spec.md](EnterpriseRetailAI-Docs/POS_API_Spec.md), [Store_Management_API_Spec.md](EnterpriseRetailAI-Docs/Store_Management_API_Spec.md), [AI_Inference_API_Spec.md](EnterpriseRetailAI-Docs/AI_Inference_API_Spec.md)

### "I'm creating new architecture documentation"
**Choose your document type:**

| Document | When | Template |
|---|---|---|
| **ADR** | New architectural decision | [new-adr-template.prompt.md](.copilot/prompts/new-adr-template.prompt.md) |
| **HLD** | New layer or domain | [new-hld-template.prompt.md](.copilot/prompts/new-hld-template.prompt.md) |
| **LLD** | New component or service | [new-lld-template.prompt.md](.copilot/prompts/new-lld-template.prompt.md) |

**Checklist:** See [.doc-rules](.doc-rules) for validation requirements (metadata, sections, links, TOGAF alignment)

---

## 🧭 Navigation Strategies

### By Question Type
- **"How does the system work end-to-end?"** → [HLD-001](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md)
- **"Why was technology X chosen?"** → [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md)
- **"How does offline work?"** → [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md)
- **"How are conflicts resolved?"** → [ADR-006](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md), [LLD-011](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md)
- **"What are the SLAs?"** → [QUICK_REFERENCE.md](QUICK_REFERENCE.md)

### By Layer
- **POS Terminal** → [HLD-002](EnterpriseRetailAI-Docs/HLD-002_POS_Application.md), [LLD-001](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md)
- **Store Edge** → [HLD-003](EnterpriseRetailAI-Docs/HLD-003_Store_Edge_Platform.md), [LLD-003](EnterpriseRetailAI-Docs/LLD-003_Store_Edge_Orchestration.md)
- **Cloud** → [HLD-004](EnterpriseRetailAI-Docs/HLD-004_Cloud_Platform_Azure.md)

### By Domain
- **Transactions** → [LLD-001](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md)
- **AI/ML** → [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md), [LLD-004–009](EnterpriseRetailAI-Docs/)
- **Data** → [HLD-006](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md), [LLD-013](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md)
- **Security** → [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)
- **Integration** → [HLD-008](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md), [LLD-014](EnterpriseRetailAI-Docs/LLD-014_API_Design.md)
- **Multitenancy** → [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md), [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md)

**Full guide:** See [AGENTS.md](AGENTS.md)

---

## 📖 Key Terminology

Unfamiliar with a term? Check [GLOSSARY.md](EnterpriseRetailAI-Docs/GLOSSARY.md) for 80+ definitions.

**Quick hits:**
- **Event Sourcing** — All state comes from immutable events, not CRUD
- **CRDT** — Data structure that auto-merges concurrent offline edits
- **Schema-Per-Tenant** — Each tenant has separate database schema (not row-level security)
- **P2PE** — Point-to-Point Encryption; POS never sees card data
- **ONNX** — Portable ML format for edge inference
- **Offline-First** — POS works indefinitely without connectivity

---

## ✅ Validation & Governance

**Creating new documentation?**
- Follow [.doc-rules](.doc-rules) (10 validation rules)
- Use templates in [.copilot/prompts/](.copilot/prompts/)
- Validate with [validate-docs.sh](validate-docs.sh)

**Submitting a PR?**
- Check [.github/pull_request_template.md](.github/pull_request_template.md)
- Automated workflow validates documentation consistency
- Ensure metadata headers, cross-references, naming conventions are correct

---

## 🤔 Still Confused?

**For new team members:** Pair with an architect; share [QUICK_REFERENCE.md](QUICK_REFERENCE.md) together

**For specific questions:** Use [AGENTS.md](AGENTS.md) to find the right document

**For AI agents:** Use skills in [.copilot/skills/](.copilot/skills/) to answer complex architectural questions

**For context:** Read [.github/copilot-instructions.md](.github/copilot-instructions.md)

---

## 📞 Key Contacts

- **Architecture Questions:** Enterprise Architecture Office
- **New ADR Submission:** Architecture Review Board (ARB)
- **Compliance/GDPR:** Legal & Compliance Team
- **Security:** Security Team
- **Operations/Deployment:** DevOps Team

---

**Ready? Pick a path above and dive in!** 🚀

**Last Updated:** July 2026 | **Next Review:** January 2027
