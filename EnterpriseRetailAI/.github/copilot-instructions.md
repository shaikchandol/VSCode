# Copilot Instructions — EnterpriseRetailAI Documentation Repository

**Purpose:** Guide GitHub Copilot and other AI assistants in understanding the EnterpriseRetailAI architecture documentation structure and conventions.

---

## Repository Overview

This workspace is a **TOGAF 10 ADM compliant enterprise architecture documentation** for a globally distributed, AI-native Point-of-Sale platform. It contains:

- **1 TOGAF Document** — Full enterprise architecture overview
- **8 Architecture Decision Records (ADRs)** — Immutable design decisions with context and rationale
- **10 High-Level Designs (HLDs)** — Layer and domain-level architecture (POS, Store Edge, Cloud, Data, AI/ML, Security, Integration, Multitenancy, Offline)
- **15 Low-Level Designs (LLDs)** — Implementation details for components and services
- **4 API Specifications** — REST/gRPC contracts for POS, Store Management, Tenant Admin, and AI Inference
- **4 Database Schemas (SQL DDL)** — PostgreSQL and SQLite schemas with full design documentation
- **3 Configuration Guides** — MLOps pipelines, drift monitoring, and ML model cards

---

## Navigation by Task Type

### When Answering Architecture Questions
1. **System overview?** → Start with [HLD-001_System_Architecture_Overview.md](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md)
2. **Why was technology X chosen?** → Check [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md), then read the specific ADR
3. **How does feature Y work?** → Find the relevant HLD (002–010), then drill into LLD (001–015)
4. **What's the schema for Z?** → Reference [LLD-013_Data_Schema_Design.md](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) and the appropriate *_DDL.sql file

### When Explaining Design Decisions
- Every architectural decision is documented in an ADR (ADR-001 through ADR-008)
- ADRs are **immutable** — never updated, only superseded (which creates a new ADR)
- Always cite the ADR ID and date when explaining a decision
- ADRs include Context, Decision, and Consequences sections — use these to justify the choice

### When Working with Schemas
- **Tenant Schema:** Multi-tenant data isolation; stored in [tenant_schema_DDL.sql](EnterpriseRetailAI-Docs/tenant_schema_DDL.sql)
- **Platform Shared Schema:** Cross-tenant metadata; see [platform_shared_DDL.sql](EnterpriseRetailAI-Docs/platform_shared_DDL.sql)
- **POS Local Schema:** On-device SQLite; see [pos_local_sqlite_DDL.sql](EnterpriseRetailAI-Docs/pos_local_sqlite_DDL.sql)
- **Store Edge Schema:** Local PostgreSQL; see [store_edge_pg_DDL.sql](EnterpriseRetailAI-Docs/store_edge_pg_DDL.sql)

### When Discussing APIs
Refer to [LLD-014_API_Design.md](EnterpriseRetailAI-Docs/LLD-014_API_Design.md) for design standards, then consult the specific API spec:
- [POS_API_Spec.md](EnterpriseRetailAI-Docs/POS_API_Spec.md) — Terminal transactions, inventory, promotions
- [Store_Management_API_Spec.md](EnterpriseRetailAI-Docs/Store_Management_API_Spec.md) — Store operations, reporting
- [Tenant_Admin_API_Spec.md](EnterpriseRetailAI-Docs/Tenant_Admin_API_Spec.md) — Tenant provisioning, configuration
- [AI_Inference_API_Spec.md](EnterpriseRetailAI-Docs/AI_Inference_API_Spec.md) — Fraud scoring, forecasting, promo ranking

---

## Key Architectural Patterns

### 1. Offline-First Design
- POS terminals operate independently with indefinite offline capability
- Transactions logged in append-only event log (SQLite)
- Sync manager queues events for store edge batch synchronization
- Conflict resolution via CRDT (Conflict-free Replicated Data Type), NOT last-write-wins
- **Docs:** [HLD-010_Offline_Architecture.md](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002_Offline_Sync_Agent.md](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md), [ADR-006_CRDT_Conflict_Resolution.md](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md)

### 2. Event Sourcing
- Immutable event log as single source of truth
- No traditional CRUD state — all state derived from events
- Events never deleted; superseded events create new records
- Enables full audit trail and temporal queries
- **Docs:** [ADR-003_Event_Sourcing.md](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md), [LLD-001_POS_Transaction_Engine.md](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md)

### 3. Schema-per-Tenant Multitenancy
- Each tenant has isolated PostgreSQL schema (NOT row-level security alone)
- Enables GDPR compliance, data residency control, and schema customization per tenant
- Provisioning via Terraform modules
- **Docs:** [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [HLD-009_Multitenancy.md](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md), [LLD-010_Tenant_Provisioning_Service.md](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md)

### 4. Three-Tier AI Inference Architecture
- **POS (Edge):** Real-time ONNX models, <100ms latency (fraud scoring, promo ranking)
- **Store Edge:** Batch processing, Phi-3 NLP fallback, local feature store
- **Cloud:** Model training, retraining, drift monitoring via Azure ML
- **Docs:** [HLD-005_AI_ML_Platform.md](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md), [LLD-015_MLOps_Pipeline_Design.md](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md)

### 5. P2PE Payment Processing
- POS never stores card data — uses P2PE (Point-to-Point Encryption) tokenization
- Offline queue for transactions when WAN is down; validation on reconnect
- Full PCI-DSS 3.2.1 compliance
- **Docs:** [ADR-007_P2PE_Payment.md](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md), [LLD-012_Payment_Service.md](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md)

---

## Six Embedded AI Use Cases

| Use Case | LLD | Model | Training | Inference | Use |
|---|---|---|---|---|---|
| **Fraud Detection** | [LLD-004](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md) | XGBoost (ONNX) | Azure ML | POS + Cloud | Real-time transaction risk scoring |
| **Demand Forecasting** | [LLD-005](EnterpriseRetailAI-Docs/LLD-005_Demand_Forecasting_Pipeline.md) | Temporal Fusion Transformer | Azure ML | Cloud | SKU-level sales predictions |
| **Personalisation & Promotions** | [LLD-006](EnterpriseRetailAI-Docs/LLD-006_Personalisation_Promotions_Engine.md) | Collab filtering + contextual bandits | Azure ML | Store Edge + Cloud | Personalized offers per customer |
| **Computer Vision Self-Checkout** | [LLD-007](EnterpriseRetailAI-Docs/LLD-007_CV_Self_Checkout.md) | YOLOv8 (ONNX) | Azure ML | Store Edge | Item detection and anti-theft |
| **NLP Store Assistant** | [LLD-008](EnterpriseRetailAI-Docs/LLD-008_NLP_Store_Assistant.md) | GPT-4o (Azure OpenAI) + RAG | N/A (pretrained) | Cloud + Phi-3 (offline) | Customer service chatbot |
| **Predictive Maintenance** | [LLD-009](EnterpriseRetailAI-Docs/LLD-009_Predictive_Maintenance.md) | Isolation Forest | Azure ML | Store Edge | Equipment health monitoring |

---

## Document Metadata Convention

Every design document follows this header:

```
| Attribute | Value |
|---|---|
| Document ID | HLD-001, LLD-004, ADR-003, etc. |
| Type | High-Level Design, Low-Level Design, ADR, etc. |
| Version | 1.0 |
| Status | Approved, Proposed, Deprecated, etc. |
| Author | Enterprise Architecture Office |
| Date | Month Year |
```

Use document status and date to assess freshness. All documents are version-controlled.

---

## Common Questions & Where to Find Answers

| Question | Document(s) |
|---|---|
| How does the system architecture work end-to-end? | [HLD-001](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md), [TOGAF document](EnterpriseRetailAI-Docs/TOGAF_GlobalRetailPOS_EA_Document.md) |
| What happens when a POS terminal loses connectivity? | [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md) |
| How is customer data isolated between tenants? | [ADR-002](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) |
| Why use ONNX on the POS instead of TensorFlow? | [ADR-005_ONNX_POS_Inference.md](EnterpriseRetailAI-Docs/ADR-005_ONNX_POS_Inference.md) |
| How are payment transactions secured and compliant? | [ADR-007](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md), [LLD-012](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md), [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md) |
| What's the transaction state machine? | [LLD-001_POS_Transaction_Engine.md](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md) |
| How do concurrent edits resolve when stores reconnect? | [ADR-006_CRDT_Conflict_Resolution.md](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md), [LLD-011](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md) |
| What are the API design standards? | [LLD-014_API_Design.md](EnterpriseRetailAI-Docs/LLD-014_API_Design.md) |
| How is the database schema organized? | [LLD-013_Data_Schema_Design.md](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) |
| What ML/AI models are deployed and where? | [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md), [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) |

---

## Standards & Conventions

- **Architecture Framework:** TOGAF 10 ADM (phases A–H)
- **Decision Process:** All significant decisions are captured in ADRs; superseded decisions create new ADRs with cross-references
- **Schema Evolution:** SQL DDL files include migration comments for version tracking
- **MLOps:** Model cards and configurations are version-controlled; drift monitoring is configured in [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md)
- **Documentation Status:** As of June 2026, architecture is stable; check individual document dates for recent changes

---

## Tips for AI Agents

1. **Always cite sources** — Reference document IDs (HLD-001, LLD-004, ADR-003) when explaining architecture
2. **Use ADRs for justification** — When explaining "why," cite the ADR context and consequences
3. **Check document metadata** — Before citing information, verify the document status and date
4. **Link, don't duplicate** — When explaining concepts, point to authoritative docs rather than summarizing
5. **Search by pattern** — Use layer (POS/Store/Cloud) or domain (Transactions/Data/AI/Security) to narrow down documents

---

**Full navigation guide:** See [AGENTS.md](AGENTS.md) in the root directory.
