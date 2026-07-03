# QUICK_REFERENCE.md — EnterpriseRetailAI Architecture Cheat Sheet

**Last Updated:** July 2026 | **Audience:** Architects, Developers, AI Agents

---

## 🏗️ System at a Glance

**Three-Tier Deployment:**
```
┌─────────────────────────────┐
│      CLOUD (Azure)          │
│  AKS | Event Hubs | Azure ML│  Training, Analytics, APIs
└──────────────┬──────────────┘
               │ Sync via Event Hubs
┌──────────────▼──────────────┐
│     STORE EDGE (K3s)        │
│  PostgreSQL | IoT Edge      │  Batch sync, local AI, reporting
└──────────────┬──────────────┘
               │ Sync every 5 min
┌──────────────▼──────────────┐
│   POS TERMINAL (Device)     │
│  Windows .NET / Android     │  Transactions, ML inference
└─────────────────────────────┘

Offline Resilience:
├─ POS: Indefinite (days/weeks/months)
├─ Store: 2-3 weeks typical
└─ Cloud: Eventual consistency via CRDT
```

---

## 📋 Key Decisions (ADRs)

| ADR | Decision | Why |
|---|---|---|
| **ADR-001** | Azure Cloud | Cost, compliance, Azure ML ecosystem |
| **ADR-002** | Schema-Per-Tenant | GDPR, isolation, customization |
| **ADR-003** | Event Sourcing | Audit trail, offline recovery, replay |
| **ADR-004** | K3s for Store Edge | Lightweight, edge-first, cost-effective |
| **ADR-005** | ONNX for POS Edge AI | Portable, <50ms latency, offline-capable |
| **ADR-006** | CRDT Conflict Resolution | Automatic merge (no manual conflicts) |
| **ADR-007** | P2PE Payments | PCI-DSS compliance, zero card data storage |
| **ADR-008** | Azure OpenAI + RAG | Best accuracy, transparency, cost |

**→ See [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md) for full details**

---

## 🔄 Offline-First Pattern

**Core Principle:** POS terminal = autonomous unit

```
POS Offline:
├─ Operations: 100% (transactions, AI, receipts)
├─ Data: Local append-only event log (SQLite)
├─ Duration: Indefinite (days/weeks)
└─ Recovery: Zero data loss ✅

Store Offline (no WAN):
├─ Operations: 90% (local reporting, POS still syncs)
├─ Data: PostgreSQL queue (up to 100K events)
├─ Duration: 2-3 weeks typical
└─ Recovery: CRDT merge resolves conflicts ✅

Complete Outage (3+ days):
├─ ~17,000 events queued (~5 MB)
├─ Recovery time: 40 minutes to sync
└─ Consistency: Eventual (all systems converge) ✅
```

**→ See [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md) for details**

---

## 🗄️ Database Schemas

| Schema | Location | Purpose | Tenancy |
|---|---|---|---|
| **Tenant Schema** | Cloud PostgreSQL | Transactions, inventory, customers | Per-tenant |
| **Platform Shared** | Cloud PostgreSQL | Metadata, audit, subscriptions | Cross-tenant |
| **POS Local** | On-device SQLite | Event log, offline queue, cache | Local |
| **Store Edge** | On-premises PostgreSQL | Sync staging, feature store, health | Local |

**→ See [LLD-013](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) and DDL files**

---

## 🤖 Six AI Use Cases

| Use Case | Model | Training | Inference | Latency | LLD |
|---|---|---|---|---|---|
| **Fraud** | XGBoost (ONNX) | Azure ML | POS + Cloud | <100ms | [LLD-004](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md) |
| **Forecasting** | TFT | Azure ML | Cloud | Batch | [LLD-005](EnterpriseRetailAI-Docs/LLD-005_Demand_Forecasting_Pipeline.md) |
| **Personalisation** | Collab + Bandits | Azure ML | Store Edge + Cloud | <500ms | [LLD-006](EnterpriseRetailAI-Docs/LLD-006_Personalisation_Promotions_Engine.md) |
| **CV Checkout** | YOLOv8 (ONNX) | Azure ML | Store Edge | <200ms | [LLD-007](EnterpriseRetailAI-Docs/LLD-007_CV_Self_Checkout.md) |
| **NLP Assistant** | GPT-4o + RAG | N/A | Cloud + Phi-3 (offline) | <2s | [LLD-008](EnterpriseRetailAI-Docs/LLD-008_NLP_Store_Assistant.md) |
| **Maintenance** | Isolation Forest | Azure ML | Store Edge | Batch | [LLD-009](EnterpriseRetailAI-Docs/LLD-009_Predictive_Maintenance.md) |

**Model Retraining:**
- **Scheduled:** Weekly (Monday 2 AM UTC)
- **On-Demand:** When prediction drift > 10%
- **SLA:** 24h retrain, 48h deploy

**→ See [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) and [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md)**

---

## 🔗 APIs & Endpoints

| API | Protocol | Auth | Consumers | Rate Limit |
|---|---|---|---|---|
| **POS API** | REST | JWT | POS terminals | 1,000 req/sec |
| **Store Mgmt** | REST | OAuth 2.0 | Store managers | 100 req/sec |
| **Tenant Admin** | REST | OAuth 2.0 | Franchisees | 10 req/sec |
| **AI Inference** | gRPC | mTLS | All tiers | Streaming |

**→ See [LLD-014](EnterpriseRetailAI-Docs/LLD-014_API_Design.md) and *_API_Spec.md files**

---

## 🔐 Security & Compliance

| Requirement | Implementation | Reference |
|---|---|---|
| **GDPR** | Schema-per-tenant (easy deletion) | ADR-002 |
| **CCPA** | Data export API + deletion SLA | HLD-007 |
| **DPDP (India)** | Data residency (no cross-border) | HLD-009 |
| **PIPL (China)** | Data residency + encryption | HLD-007 |
| **PCI-DSS** | P2PE tokenisation (no card storage) | ADR-007 |
| **Zero Trust** | mTLS, OAuth 2.0, least privilege | HLD-007 |

**→ See [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)**

---

## 📊 Key Metrics & SLAs

| Metric | Target | Current | Status |
|---|---|---|---|
| **POS Availability** | 99.9% | 99.95% | ✅ |
| **Store Uptime** | 99.5% | 99.67% | ✅ |
| **Cloud SLA** | 99.99% | 99.99% | ✅ |
| **Fraud Detection Latency** | <100ms p99 | 45ms | ✅ |
| **Sync Latency (to cloud)** | <5 minutes | 120 seconds | ✅ |
| **GDPR Data Deletion** | <30 days | 24 hours | ✅ |

**→ See [HLD-001](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md) for SLA details**

---

## 🚀 Multitenancy Model

**Schema-Per-Tenant Isolation:**
```
┌──────────────────────────────────────────┐
│  PostgreSQL Database (Cloud)             │
│                                          │
│  ┌─ Platform Shared Schema ──────┐      │
│  │  tenant_metadata              │      │
│  │  subscriptions                │      │
│  │  audit_log                    │      │
│  └───────────────────────────────┘      │
│                                          │
│  ┌─ Tenant 1 Schema ────┐  ┌─ Tenant 2 Schema ────┐
│  │  transactions        │  │  transactions        │
│  │  inventory           │  │  inventory           │
│  │  customers           │  │  customers           │
│  │  employees           │  │  employees           │
│  └──────────────────────┘  └──────────────────────┘
│                                          │
│  ┌─ Tenant N Schema ────────────┐       │
│  │  (custom schema per tenant)  │       │
│  └──────────────────────────────┘       │
└──────────────────────────────────────────┘
```

**Benefits:**
- ✅ GDPR compliance (DELETE SCHEMA)
- ✅ Performance isolation (independent indexes)
- ✅ Custom fields per tenant
- ✅ Data residency (different regions)

**→ See [ADR-002](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md) and [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md)**

---

## 🔄 Sync & Conflict Resolution

**Sync Flow:**
```
POS Local Event Log
  ↓ (every 5 minutes, batched)
Store Edge Queue (PostgreSQL)
  ↓ (streaming to Event Hubs)
Cloud Event Hubs
  ↓ (Azure Functions process)
Azure SQL (append-only event table)
  ↓ (analytics, ML training, reporting)
Data Warehouse / BI
```

**Conflict Resolution (CRDT):**
- Type: Conflict-free Replicated Data Type
- When: Concurrent offline edits + reconnect
- How: Automatic merge (operations + timestamps + version vectors)
- Result: All systems converge to same state ✅

**Example:** Store A and B both offline, edit product qty
- Store A: qty -= 5
- Store B: qty -= 3
- Merge: qty -= 8 (both operations applied) ✅

**→ See [ADR-006](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md) and [LLD-011](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md)**

---

## 🧭 Navigation Quick Links

### By Layer
- **POS Terminal:** [HLD-002](EnterpriseRetailAI-Docs/HLD-002_POS_Application.md), [LLD-001](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md)
- **Store Edge:** [HLD-003](EnterpriseRetailAI-Docs/HLD-003_Store_Edge_Platform.md), [LLD-003](EnterpriseRetailAI-Docs/LLD-003_Store_Edge_Orchestration.md)
- **Cloud:** [HLD-004](EnterpriseRetailAI-Docs/HLD-004_Cloud_Platform_Azure.md)

### By Domain
- **Transactions:** [LLD-001](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md), [LLD-012](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md)
- **Data:** [HLD-006](EnterpriseRetailAI-Docs/HLD-006_Data_Architecture.md), [LLD-013](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md)
- **Offline:** [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md)
- **AI/ML:** [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md), [LLD-004-009](EnterpriseRetailAI-Docs/)
- **Security:** [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)
- **Integration:** [HLD-008](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md), [LLD-014](EnterpriseRetailAI-Docs/LLD-014_API_Design.md)
- **Multitenancy:** [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md), [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md)

### By Question Type
- **"How does the system work end-to-end?"** → [HLD-001](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md)
- **"Why was technology X chosen?"** → [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md)
- **"How do offline and sync work?"** → [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md)
- **"How do I train and deploy a model?"** → [LLD-015](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md), [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md)
- **"How is tenant data isolated?"** → [ADR-002](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md)

---

## 🎯 Common Tasks

### "I'm onboarding a new tenant"
1. Read [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md) (provisioning service)
2. Refer to [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) (multitenancy model)
3. Check [tenant_schema_DDL.sql](EnterpriseRetailAI-Docs/tenant_schema_DDL.sql) (schema template)

### "I need to add a new AI use case"
1. Start with [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) (AI/ML platform)
2. Review [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) (model card template)
3. Create LLD-XXX detailing your model
4. Update [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md) (training pipeline)
5. Update [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md) (drift thresholds)

### "A store went offline for 3 days"
1. POS logged all events locally (zero loss) ✅
2. On reconnect, store edge pulls events (5-min batches)
3. CRDT resolves any concurrent edits
4. Events stream to cloud (40 mins total recovery)
5. See [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md) for details

### "I'm integrating a new external system"
1. Read [HLD-008](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md) (integration patterns)
2. Review [LLD-014](EnterpriseRetailAI-Docs/LLD-014_API_Design.md) (API design standards)
3. Choose pattern: REST, gRPC, Event Hubs, or offline queue
4. Implement with auth (OAuth 2.0, mTLS, API key)
5. Add to [AGENTS.md](AGENTS.md) navigation guide

---

## 📞 Key Contacts

For questions about:
- **Architecture:** Enterprise Architecture Office
- **ADRs:** Architecture Review Board (ARB)
- **Operations:** DevOps Team
- **Compliance:** Legal/Compliance Team
- **Security:** Security Team

---

**For detailed navigation, see [AGENTS.md](AGENTS.md) | Last Updated: July 2026**
