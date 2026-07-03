# AGENTS.md — EnterpriseRetailAI Documentation Navigation Guide

**Project:** EnterpriseRetailAI — Global Retail POS Platform  
**Type:** Enterprise Architecture Documentation Repository  
**Standard:** TOGAF 10 ADM  
**Last Updated:** July 2026

---

## 📋 Quick Start for AI Agents

This workspace contains **enterprise architecture documentation** for a multitenant, AI-native POS platform. Use this guide to navigate the documentation efficiently when answering questions about system design, integration points, data flows, and architecture decisions.

### Directory Structure
```
EnterpriseRetailAI-Docs/
├── TOGAF_GlobalRetailPOS_EA_Document.md          # Full enterprise architecture document
├── ADR-*.md + ADR_Index.md                       # Architecture Decision Records
├── HLD-*.md                                      # High-Level Designs (10 documents)
├── LLD-*.md                                      # Low-Level Designs (15 documents)
├── *_API_Spec.md                                 # API specifications
├── *_DDL.sql                                     # Database schemas
├── *_Config.md + Model_Cards.md                  # Configuration & ML models
└── README.md                                     # Project overview
```

---

## 🤖 Agent & Documentation Guidance

Use these repository-level artifacts to answer questions and validate contributions:
- [GETTING_STARTED.md](GETTING_STARTED.md) — onboarding guide for contributors and AI agents
- [DOCUMENT_MANIFEST.md](DOCUMENT_MANIFEST.md) — repository manifest for documentation artifacts, validation tools, and skills
- [.doc-rules](.doc-rules) — validation rules for architecture documentation
- [validate-docs.sh](validate-docs.sh) — local documentation validation script
- [.github/copilot-instructions.md](.github/copilot-instructions.md) — Copilot context and patterns
- [.copilot/skills/](.copilot/skills/) — specialized agent skills, including performance scaling
- [.copilot/prompts/](.copilot/prompts/) — authoring templates for ADRs, HLDs, LLDs

---

## 🤖 Agent & Documentation Guidance

Use these repository-level artifacts to answer questions and validate contributions:
- [GETTING_STARTED.md](GETTING_STARTED.md) — onboarding guide for contributors and agents
- [DOCUMENT_MANIFEST.md](DOCUMENT_MANIFEST.md) — repository manifest for documentation artifacts, validation tools, and skills
- [.doc-rules](.doc-rules) — validation rules for architecture documentation
- [validate-docs.sh](validate-docs.sh) — local documentation validation script
- [.github/copilot-instructions.md](.github/copilot-instructions.md) — Copilot context and patterns
- [.copilot/skills/](.copilot/skills/) — specialized agent skills, including performance scaling
- [.copilot/prompts/](.copilot/prompts/) — authoring templates for ADRs, HLDs, LLDs

---

## 🏗️ System Architecture at a Glance

**Three-Tier Deployment:**
1. **POS Edge (Device Layer):** Windows .NET / Android terminals with local SQLite, offline event log, ONNX inference
2. **Store Edge (On-Premises):** K3s orchestration, PostgreSQL, local AI, sync manager, IoT Edge integration
3. **Cloud (Azure Multi-Region):** AKS, Event Hubs, Azure ML, Azure SQL, APIM, global topology

**Key Architectural Patterns:**
- **Multitenancy:** Schema-per-tenant isolation (ADR-002)
- **Transactions:** Event sourcing with CRDT-based conflict resolution (ADR-003, ADR-006)
- **Offline Resilience:** Indefinite offline operation at POS and store levels with sync recovery
- **AI Inference:** Edge-first with ONNX Runtime (ADR-005), cloud ML via Azure ML
- **Payments:** P2PE tokenisation (ADR-007) with offline queuing and settlement

**Six AI Use Cases:**
1. Fraud Detection (LLD-004) — ONNX model at POS
2. Demand Forecasting (LLD-005) — Temporal Fusion Transformer in Azure ML
3. Personalisation & Promotions (LLD-006) — Collaborative filtering + contextual bandits
4. Computer Vision Self-Checkout (LLD-007) — YOLOv8 item detection
5. NLP Store Assistant (LLD-008) — GPT-4o + RAG with offline Phi-3 fallback
6. Predictive Maintenance (LLD-009) — IoT telemetry anomaly detection

---

## 📚 Document Navigation by Use Case

### When answering questions about...

| Question Type | Primary Document | Supporting Docs |
|---|---|---|
| **System architecture & topology** | [HLD-001](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md) | [TOGAF document](EnterpriseRetailAI-Docs/TOGAF_GlobalRetailPOS_EA_Document.md) |
| **POS terminal functionality** | [HLD-002](EnterpriseRetailAI-Docs/HLD-002_POS_Application.md), [LLD-001](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md) | [POS_API_Spec.md](EnterpriseRetailAI-Docs/POS_API_Spec.md), [pos_local_sqlite_DDL.sql](EnterpriseRetailAI-Docs/pos_local_sqlite_DDL.sql) |
| **Store edge & K3s orchestration** | [HLD-003](EnterpriseRetailAI-Docs/HLD-003_Store_Edge_Platform.md), [LLD-003](EnterpriseRetailAI-Docs/LLD-003_Store_Edge_Orchestration.md) | [ADR-004](EnterpriseRetailAI-Docs/ADR-004_K3s_Store_Edge.md) |
| **Cloud platform (Azure)** | [HLD-004](EnterpriseRetailAI-Docs/HLD-004_Cloud_Platform_Azure.md) | [ADR-001](EnterpriseRetailAI-Docs/ADR-001_Azure_Cloud_Platform.md) |
| **Offline & sync mechanisms** | [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md), [LLD-011](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md) | [ADR-003](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md), [ADR-006](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md) |
| **Payment processing** | [LLD-012](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md) | [ADR-007](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md) |
| **Data architecture & multitenancy** | [HLD-006](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md), [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md), [LLD-013](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) | [ADR-002](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [tenant_schema_DDL.sql](EnterpriseRetailAI-Docs/tenant_schema_DDL.sql) |
| **AI/ML models & training** | [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md), [LLD-015](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md) | [LLD-004 through LLD-009](EnterpriseRetailAI-Docs/), [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md), [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md) |
| **Security, compliance & zero trust** | [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md) | ADR records for specific technologies |
| **API design & integration** | [HLD-008](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md), [LLD-014](EnterpriseRetailAI-Docs/LLD-014_API_Design.md) | [POS_API_Spec.md](EnterpriseRetailAI-Docs/POS_API_Spec.md), [Store_Management_API_Spec.md](EnterpriseRetailAI-Docs/Store_Management_API_Spec.md), [Tenant_Admin_API_Spec.md](EnterpriseRetailAI-Docs/Tenant_Admin_API_Spec.md), [AI_Inference_API_Spec.md](EnterpriseRetailAI-Docs/AI_Inference_API_Spec.md) |
| **Fraud detection AI** | [LLD-004](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md) | [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) (AI/ML Platform section) |
| **Demand forecasting AI** | [LLD-005](EnterpriseRetailAI-Docs/LLD-005_Demand_Forecasting_Pipeline.md) | [LLD-015](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md), [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md) |
| **Personalisation & promotions AI** | [LLD-006](EnterpriseRetailAI-Docs/LLD-006_Personalisation_Promotions_Engine.md) | [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) |
| **Computer vision self-checkout** | [LLD-007](EnterpriseRetailAI-Docs/LLD-007_CV_Self_Checkout.md) | [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) |
| **NLP store assistant** | [LLD-008](EnterpriseRetailAI-Docs/LLD-008_NLP_Store_Assistant.md) | [ADR-008](EnterpriseRetailAI-Docs/ADR-008_Azure_OpenAI_NLP.md), [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) |
| **Predictive maintenance** | [LLD-009](EnterpriseRetailAI-Docs/LLD-009_Predictive_Maintenance.md) | [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) |
| **Tenant provisioning & onboarding** | [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md) | [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) |
| **Architecture decisions & rationale** | [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md) | Individual ADR files (ADR-001 through ADR-008) |

---

## 🔑 Key Architectural Decisions

Refer to [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md) for all decisions. Key ADRs:

- **ADR-001:** Azure as primary cloud platform (rationale, cost, compliance)
- **ADR-002:** Schema-per-tenant isolation (security, performance, multi-geography)
- **ADR-003:** Event sourcing for transaction state (audit trail, offline recovery, replay)
- **ADR-004:** K3s for store edge orchestration (lightweight, edge-first, cost)
- **ADR-005:** ONNX Runtime for POS edge AI (portability, performance, offline)
- **ADR-006:** CRDT-based offline conflict resolution (no manual merge, eventual consistency)
- **ADR-007:** P2PE payment tokenisation (PCI-DSS compliance, token vault)
- **ADR-008:** Azure OpenAI + RAG for NLP assistant (accuracy, transparency, cost)

---

## 🗄️ Database Schema Navigation

| Schema | File | Purpose |
|---|---|---|
| **Tenant Schema** | [tenant_schema_DDL.sql](EnterpriseRetailAI-Docs/tenant_schema_DDL.sql) | Full per-tenant PostgreSQL schema (transactions, inventory, customers, events) |
| **Platform Shared Schema** | [platform_shared_DDL.sql](EnterpriseRetailAI-Docs/platform_shared_DDL.sql) | Shared across all tenants (tenant metadata, provisioning, audit) |
| **POS Local Schema** | [pos_local_sqlite_DDL.sql](EnterpriseRetailAI-Docs/pos_local_sqlite_DDL.sql) | Local SQLite on POS terminal (append-only event log, offline queue) |
| **Store Edge Schema** | [store_edge_pg_DDL.sql](EnterpriseRetailAI-Docs/store_edge_pg_DDL.sql) | Store-local PostgreSQL (sync staging, local AI features, health checks) |

**Schema Design Details:** See [LLD-013 Data Schema Design](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md)

---

## 🔗 API Endpoints Summary

| API | File | Purpose | Consumers |
|---|---|---|---|
| **POS API** | [POS_API_Spec.md](EnterpriseRetailAI-Docs/POS_API_Spec.md) | Transaction, inventory, promotions | POS terminals |
| **Store Management API** | [Store_Management_API_Spec.md](EnterpriseRetailAI-Docs/Store_Management_API_Spec.md) | Store operations, reporting | Store managers, HQ analysts |
| **Tenant Admin API** | [Tenant_Admin_API_Spec.md](EnterpriseRetailAI-Docs/Tenant_Admin_API_Spec.md) | Tenant provisioning, configuration | Franchisee admins, HQ IT |
| **AI Inference API** | [AI_Inference_API_Spec.md](EnterpriseRetailAI-Docs/AI_Inference_API_Spec.md) | Fraud scoring, demand forecast, promo ranking | All tiers (POS, Store Edge, Cloud) |

**API Design Standards:** See [LLD-014 API Design](EnterpriseRetailAI-Docs/LLD-014_API_Design.md)

---

## 🤖 AI/ML Models Quick Reference

All six AI use cases documented in:
- **[Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md)** — Individual model specifications, performance metrics
- **[MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md)** — Training, retraining, CI/CD pipelines
- **[Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md)** — Monitoring configurations, alert thresholds

| Use Case | LLD | Model Type | Training | Inference |
|---|---|---|---|---|
| Fraud Detection | [LLD-004](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md) | XGBoost (ONNX) | Azure ML | POS + Cloud (dual) |
| Demand Forecasting | [LLD-005](EnterpriseRetailAI-Docs/LLD-005_Demand_Forecasting_Pipeline.md) | Temporal Fusion Transformer | Azure ML | Cloud only |
| Personalisation | [LLD-006](EnterpriseRetailAI-Docs/LLD-006_Personalisation_Promotions_Engine.md) | Collab filtering + bandits | Azure ML | Store Edge + Cloud |
| CV Self-Checkout | [LLD-007](EnterpriseRetailAI-Docs/LLD-007_CV_Self_Checkout.md) | YOLOv8 (ONNX) | Azure ML | Store Edge |
| NLP Assistant | [LLD-008](EnterpriseRetailAI-Docs/LLD-008_NLP_Store_Assistant.md) | GPT-4o (Azure OpenAI) + RAG | N/A (pretrained) | Cloud + Phi-3 (offline) |
| Predictive Maintenance | [LLD-009](EnterpriseRetailAI-Docs/LLD-009_Predictive_Maintenance.md) | Isolation Forest | Azure ML | Store Edge |

---

## 💡 Common Patterns & Conventions

### 1. **Offline-First Design**
- **Pattern:** Append-only event log at POS → queue for sync → store edge batch sync → cloud persistence
- **Conflict Resolution:** CRDT (LLD-011), NOT last-write-wins
- **Example:** Transaction void/return with concurrent offline edits → CRDT merge
- **Docs:** [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md)

### 2. **Event Sourcing**
- **Pattern:** Immutable event log as source of truth, not CRUD state
- **Storage:** SQLite (POS), PostgreSQL (Store Edge), Azure Event Hubs (Cloud)
- **Retention:** Event log never deleted, superseded events create new records
- **Docs:** [ADR-003](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md), [LLD-001](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md)

### 3. **Schema-per-Tenant Multitenancy**
- **Isolation:** Separate PostgreSQL schema per tenant (NOT row-level security alone)
- **Benefits:** GDPR compliance, data residency control, custom schemas per tenant
- **Provisioning:** Terraform modules in tenant provisioning service
- **Docs:** [ADR-002](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md)

### 4. **Three-Tier AI Inference**
- **POS (Edge):** Real-time, ONNX models, <100ms latency (fraud, promo ranking)
- **Store Edge:** Batch processing, Phi-3 NLP fallback, local feature store
- **Cloud:** Heavy compute, model training, retraining, drift monitoring
- **Docs:** [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md), [LLD-015](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md)

### 5. **P2PE Payment Processing**
- **Flow:** POS → Payment Gateway (P2PE tokenised) → Bank → Settlement
- **Offline:** Offline-queue transactions with token validation on reconnect
- **Compliance:** PCI-DSS 3.2.1, no card data stored locally
- **Docs:** [LLD-012](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md), [ADR-007](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md)

---

## 📖 How to Navigate This Repository

### **For Architecture Questions:**
1. Start with [HLD-001](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md) for system context
2. Drill into the appropriate HLD (002–010) based on the layer or domain
3. Reference specific LLDs (001–015) for implementation details
4. Check ADR_Index for decision rationale

### **For Implementation Details:**
1. Find the relevant LLD (001–015) using the table above
2. Cross-reference API specs (*_API_Spec.md) for contracts
3. Refer to SQL DDL files for schema details
4. Check MLOps and model card files for AI/ML specifics

### **For Security & Compliance:**
1. Start with [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)
2. Refer to specific ADRs (e.g., ADR-002 for GDPR, ADR-007 for PCI-DSS)
3. Cross-check API design (LLD-014) for rate limiting, auth

### **For Decision Context:**
1. Check [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md) for all decisions
2. Each ADR lists context, decision, and consequences
3. ADRs are immutable — superseded decisions link to new ADRs

---

## 🚀 Tips for Efficient Navigation

- **Search by Layer:** POS (HLD-002, LLD-001) | Store Edge (HLD-003, LLD-003) | Cloud (HLD-004, LLD-*)
- **Search by Domain:** Transactions | Data | AI/ML | Security | Integration | Offline
- **Use the README:** [README.md](EnterpriseRetailAI-Docs/README.md) has a full document index with descriptions
- **Link Pattern:** All document references above are clickable Markdown links to actual files
- **Version Control:** Documents are versioned; check header metadata (Version, Date, Status)

---

## 📝 Document Metadata Convention

Every design document follows this header structure:
```
| Attribute | Value |
|---|---|
| Document ID | HLD-001, LLD-004, etc. |
| Type | High-Level Design, Low-Level Design, ADR, etc. |
| Version | 1.0 |
| Status | Approved, Proposed, Deprecated, etc. |
| Author | Enterprise Architecture Office |
| Date | Month Year |
```

Use this metadata to identify document scope and freshness.

---

## ❓ When to Ask for More Context

If you encounter:
- **"How does fraud detection work?"** → [LLD-004](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md)
- **"What happens when the store goes offline?"** → [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md)
- **"How is data isolated for different tenants?"** → [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md), [ADR-002](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md)
- **"Why ONNX over TensorFlow on the POS?"** → [ADR-005](EnterpriseRetailAI-Docs/ADR-005_ONNX_POS_Inference.md)
- **"What's the transaction state machine?"** → [LLD-001](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md)
- **"How do conflicting edits resolve offline?"** → [ADR-006](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md), [LLD-011](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md)

---

## 🔄 Repository Maintenance Notes

- **Documentation Standard:** TOGAF 10 ADM
- **Update Frequency:** Architecture stable as of June 2026
- **ADR Process:** Decisions are immutable; superseded decisions create new ADRs with cross-references
- **Schema Versioning:** SQL DDL files include migration comments for schema evolution
- **MLOps Versioning:** Model cards and configs are version-controlled with drift monitoring

---

**Questions? Refer to the README.md or the navigation table above. All documents are cross-linked.**
