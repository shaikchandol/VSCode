# EnterpriseRetailAI — Project Documentation

## Multitenant Global Retail POS Platform · Azure-Native · AI-First

---

| Attribute | Value |
|---|---|
| Project | EnterpriseRetailAI |
| Architecture Standard | TOGAF 10 ADM |
| Cloud Platform | Microsoft Azure |
| Version | 1.0.0 |
| Last Updated | June 2026 |
| Document Owner | Enterprise Architecture Office |

---

## Project Overview

EnterpriseRetailAI is a globally distributed, AI-native, multitenant Point-of-Sale platform built for enterprise retail operations spanning corporate-owned stores and global franchisees. The platform delivers full offline resilience at both POS-terminal and store levels, with six embedded AI use cases across the entire retail value chain.

---

## Getting Started

**New to this documentation?** Start here:
1. [GETTING_STARTED.md](../GETTING_STARTED.md) — 5-minute orientation guide
2. [QUICK_REFERENCE.md](../QUICK_REFERENCE.md) — One-page architecture cheat sheet
3. [AGENTS.md](../AGENTS.md) — Document navigation by question type

**For AI Agents & Tools:**
- [.github/copilot-instructions.md](../.github/copilot-instructions.md) — Copilot context and patterns
- [.copilot/skills/](../.copilot/skills/) — Specialized skills (MLOps, multitenancy, offline-first, integration, security, data architecture, performance scaling)
- [.copilot/prompts/](../.copilot/prompts/) — Templates for creating new ADRs, HLDs, LLDs
- [DOCUMENT_MANIFEST.md](../DOCUMENT_MANIFEST.md) — top-level manifest for docs, workflows, and skill artifacts
- [validate-docs.sh](../validate-docs.sh) — local validation runner for documentation and schema files

**Terminology:**
- [GLOSSARY.md](GLOSSARY.md) — 80+ domain terms with cross-references

---

## Document Index

### 00 — TOGAF Enterprise Architecture
| File | Description |
|---|---|
| `00_TOGAF/TOGAF_GlobalRetailPOS_EA_Document.md` | Full 14-page TOGAF ADM document covering all phases A–H |

---

### 01 — High-Level Design (HLD)
| File | Description |
|---|---|
| `01_HLD/HLD-001_System_Architecture_Overview.md` | End-to-end system architecture, component map, deployment topology |
| `01_HLD/HLD-002_POS_Application.md` | POS application stack, offline mode, AI modules, payment handling |
| `01_HLD/HLD-003_Store_Edge_Platform.md` | Store edge server, K3s, IoT Edge, local AI, sync manager |
| `01_HLD/HLD-004_Cloud_Platform_Azure.md` | AKS, APIM, Event Hubs, Azure SQL, global topology |
| `01_HLD/HLD-005_AI_ML_Platform.md` | Azure ML, Azure OpenAI, all 6 AI use cases, MLOps |
| `01_HLD/HLD-006_Data_Architecture.md` | Schema-per-tenant, event sourcing, data flows, MDM |
| `01_HLD/HLD-007_Security_Compliance.md` | Zero Trust, PCI-DSS, GDPR, CCPA, DPDP, PIPL |
| `01_HLD/HLD-008_Integration_Architecture.md` | API strategy, event-driven integration, external systems |
| `01_HLD/HLD-009_Multitenancy.md` | Tenant hierarchy, provisioning, isolation, data residency |
| `01_HLD/HLD-010_Offline_Architecture.md` | POS offline, store offline, sync recovery, conflict resolution |

---

### 02 — Low-Level Design (LLD)
| File | Description |
|---|---|
| `02_LLD/LLD-001_POS_Transaction_Engine.md` | Transaction lifecycle, state machine, receipt, void, return |
| `02_LLD/LLD-002_Offline_Sync_Agent.md` | Outbox pattern, CRDT, vector clocks, sync protocol |
| `02_LLD/LLD-003_Store_Edge_Orchestration.md` | K3s config, service mesh, pod specs, health checks |
| `02_LLD/LLD-004_Fraud_Detection_Service.md` | Feature engineering, ONNX model, scoring pipeline, alert flow |
| `02_LLD/LLD-005_Demand_Forecasting_Pipeline.md` | TFT model, Azure ML pipeline, feature store, retraining |
| `02_LLD/LLD-006_Personalisation_Promotions_Engine.md` | Collab filtering, contextual bandits, promo resolver |
| `02_LLD/LLD-007_CV_Self_Checkout.md` | YOLOv8 pipeline, item detection, weight integration, anti-theft |
| `02_LLD/LLD-008_NLP_Store_Assistant.md` | RAG architecture, Azure OpenAI, Phi-3 offline, intent routing |
| `02_LLD/LLD-009_Predictive_Maintenance.md` | IoT telemetry schema, anomaly detection, alert service |
| `02_LLD/LLD-010_Tenant_Provisioning_Service.md` | Provisioning pipeline, Terraform modules, schema bootstrap |
| `02_LLD/LLD-011_Event_Sync_CRDT_Engine.md` | Event schema, CRDT types, merge algorithm, idempotency |
| `02_LLD/LLD-012_Payment_Service.md` | Online/offline payment, P2PE, token engine, settlement |
| `02_LLD/LLD-013_Data_Schema_Design.md` | Full DB schema per domain, indexes, partitioning, RLS |
| `02_LLD/LLD-014_API_Design.md` | REST + gRPC specs, APIM policies, versioning, rate limits |
| `02_LLD/LLD-015_MLOps_Pipeline_Design.md` | Azure ML pipelines, model registry, drift monitoring, CD4ML |

---

### 03 — Architecture Decision Records
| File | Description |
|---|---|
| `03_ADR/ADR_Index.md` | Index of all ADRs with status |
| `03_ADR/ADR-001_Azure_Cloud_Platform.md` | Azure selection rationale |
| `03_ADR/ADR-002_Schema_Per_Tenant.md` | Tenant isolation model decision |
| `03_ADR/ADR-003_Event_Sourcing.md` | Event sourcing vs. CRUD for transactions |
| `03_ADR/ADR-004_K3s_Store_Edge.md` | K3s vs. Docker Compose vs. bare metal |
| `03_ADR/ADR-005_ONNX_POS_Inference.md` | ONNX Runtime for edge AI |
| `03_ADR/ADR-006_CRDT_Conflict_Resolution.md` | CRDT vs. last-write-wins vs. manual merge |
| `03_ADR/ADR-007_P2PE_Payment.md` | P2PE tokenisation approach |
| `03_ADR/ADR-008_Azure_OpenAI_NLP.md` | GPT-4o + RAG vs. fine-tuned model |

---

### 05 — API Specifications
| File | Description |
|---|---|
| `05_API_Specs/POS_API_Spec.md` | POS terminal REST API spec |
| `05_API_Specs/Store_Management_API_Spec.md` | Store admin API spec |
| `05_API_Specs/Tenant_Admin_API_Spec.md` | Franchisee admin API spec |
| `05_API_Specs/AI_Inference_API_Spec.md` | AI services API spec |

---

### 06 — Database Schemas
| File | Description |
|---|---|
| `06_DB_Schemas/tenant_schema_DDL.sql` | Full PostgreSQL DDL per tenant schema |
| `06_DB_Schemas/platform_shared_DDL.sql` | Shared platform schema DDL |
| `06_DB_Schemas/pos_local_sqlite_DDL.sql` | POS local SQLite schema |
| `06_DB_Schemas/store_edge_pg_DDL.sql` | Store edge PostgreSQL schema |

---

### 07 — MLOps
| File | Description |
|---|---|
| `07_MLOps/MLOps_Pipeline_Config.md` | Azure ML pipeline YAML configs |
| `07_MLOps/Model_Cards.md` | Model cards for all 6 AI use cases |
| `07_MLOps/Drift_Monitoring_Config.md` | Evidently AI monitoring configuration |

---

## Architecture Quick Reference

```
POS Terminal (offline-first)
    └── Store Edge Server (K3s + IoT Edge + PostgreSQL)
            └── Azure Cloud (AKS + Event Hubs + Azure SQL)
                    ├── AI Platform (Azure ML + Azure OpenAI)
                    ├── API Management (APIM — per tenant)
                    ├── Security (Sentinel + Defender + Key Vault)
                    └── Data Platform (Synapse + Data Lake + Purview)
```

## Six AI Use Cases

| # | Use Case | Inference Location | Model |
|---|---|---|---|
| 1 | Demand Forecasting | Cloud (Azure ML) | Temporal Fusion Transformer |
| 2 | Fraud Detection | POS Edge + Cloud | LightGBM ONNX + Neural Net |
| 3 | Personalised Promotions | Store Edge + Cloud | Collaborative Filtering + Bandits |
| 4 | Computer Vision (Self-Checkout) | Store Edge | YOLOv8 ONNX |
| 5 | NLP Store Assistant | Cloud + SLM offline | GPT-4o + RAG / Phi-3 Mini |
| 6 | Predictive Maintenance | Cloud + Edge | Isolation Forest + LSTM |

---

*EnterpriseRetailAI · Enterprise Architecture Office · Confidential*
