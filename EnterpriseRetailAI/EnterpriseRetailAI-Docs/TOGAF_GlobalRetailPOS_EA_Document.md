# TOGAF Enterprise Architecture Document
## Multitenant Global Enterprise Retail POS Platform
### Complete AI Engineering Architecture — Azure-Native

---

> **Classification:** Restricted — Enterprise Architecture  
> **Standard:** TOGAF 10 ADM  
> **Version:** 1.0.0  
> **Date:** June 2026  
> **Author:** Enterprise Architecture Office  
> **Reviewed By:** CTO, CISO, CDO, Head of Retail Technology  

---

## Document Version History

| Version | Date | Author | Description |
|---|---|---|---|
| 0.1 | 2026-01 | EA Office | Initial Draft — Vision & Business Architecture |
| 0.5 | 2026-03 | EA Office | Technology & AI Architecture added |
| 0.8 | 2026-04 | EA Office | Offline Architecture, Security, Compliance |
| 1.0 | 2026-06 | EA Office | Approved Baseline — Full ADM Cycle |

---

## TOGAF ADM Phase Map

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TOGAF ADM CYCLE                                │
│                                                                         │
│              ┌─────────────┐                                           │
│              │ Preliminary │  Architecture Capability & Framework      │
│              └──────┬──────┘                                           │
│                     │                                                   │
│              ┌──────▼──────┐                                           │
│              │   Phase A   │  Architecture Vision                      │
│              └──────┬──────┘                                           │
│         ┌───────────┼───────────┐                                      │
│    ┌────▼────┐  ┌───▼────┐  ┌──▼──────┐                              │
│    │ Phase B │  │Phase C │  │ Phase D │  Business → App/Data → Tech  │
│    └────┬────┘  └───┬────┘  └──┬──────┘                              │
│         └───────────┼───────────┘                                      │
│              ┌──────▼──────┐                                           │
│              │   Phase E   │  Opportunities & Solutions                │
│              └──────┬──────┘                                           │
│              ┌──────▼──────┐                                           │
│              │   Phase F   │  Migration Planning                       │
│              └──────┬──────┘                                           │
│              ┌──────▼──────┐                                           │
│              │   Phase G   │  Implementation Governance                │
│              └──────┬──────┘                                           │
│              ┌──────▼──────┐                                           │
│              │   Phase H   │  Architecture Change Management           │
│              └─────────────┘                                           │
│                    ▲                                                    │
│              Requirements Management (continuous)                      │
└─────────────────────────────────────────────────────────────────────────┘
```

---

# PAGE 1 — PRELIMINARY PHASE: Architecture Capability & Principles

---

## 1.1 Scope of This Architecture

This document establishes the **Target Enterprise Architecture** for a next-generation, multitenant, AI-first Global Retail Point-of-Sale (POS) platform supporting:

- **Mixed deployment model:** Corporate-owned stores (HQ) + global franchisees
- **Scale:** 5,000+ stores across multiple geographies and regulatory jurisdictions
- **Resilience:** Full operation under POS-offline and Store-offline conditions
- **Cloud platform:** Microsoft Azure (AKS, IoT Edge, Azure OpenAI, Azure ML)
- **Multitenancy:** Schema-per-tenant isolation per franchisee entity
- **AI Engineering:** Six priority AI use cases embedded across all architecture layers

---

## 1.2 Architecture Principles

### P1 — Offline-First by Design
Every POS terminal and store edge node operates fully autonomously without cloud connectivity. Online synchronization is opportunistic, not mandatory.

### P2 — AI at the Edge, Intelligence in the Cloud
AI inference for latency-critical use cases (fraud detection, self-checkout) runs on-device or at the store edge. Training, retraining, and orchestration live in Azure ML.

### P3 — Schema-per-Tenant Isolation
Each franchisee receives a dedicated database schema. No cross-tenant data leakage is architecturally possible at the storage layer.

### P4 — Zero Trust Security
No implicit trust at any network boundary — POS terminal, store edge, cloud, or API. Every identity is verified; every request is authorized; every payload is encrypted.

### P5 — Compliance by Architecture
PCI-DSS, GDPR, CCPA, ISO 27001, India DPDP, China PIPL controls are embedded as architectural constraints, not post-deployment overlays.

### P6 — Event-Driven Consistency
All state changes propagate as immutable events. Eventual consistency is the norm; strong consistency is reserved for financial transactions only.

### P7 — Continuous AI Governance
All AI models are versioned, auditable, explainable, and subject to automated bias and drift monitoring before and after deployment.

### P8 — Franchise Autonomy within Platform Guardrails
Franchisees configure their tenant within HQ-defined policy boundaries. They cannot override compliance, security, or data residency controls.

---

## 1.3 Stakeholder Register

| Stakeholder | Role | Architecture Concern |
|---|---|---|
| Group CTO | Technology Strategy | Platform scalability, cloud cost, vendor lock-in |
| Group CISO | Security | Zero Trust, PCI-DSS, data sovereignty |
| Group CDO | Data | AI model governance, tenant data isolation |
| HQ Retail Ops | Business Operations | Uptime, offline resilience, store SLAs |
| Franchise Owners | Business Partners | Tenant autonomy, billing, POS UX |
| Store Managers | Operations | Daily operations, reports, inventory |
| Cashiers / Store Staff | End Users | POS speed, simplicity, AI assist |
| Payment Processors | External Partners | PCI compliance, integration SLA |
| Regulatory Bodies | Compliance | GDPR, DPDP, PIPL, PCI-DSS audit evidence |

---

## 1.4 Architecture Drivers

| Driver | Description | Priority |
|---|---|---|
| Global Scale | Support 5000+ stores, multiple currencies, languages, tax regimes | Critical |
| Offline Resilience | POS and store must operate 100% offline indefinitely | Critical |
| AI-First Retail | Embed AI across all customer and operational touchpoints | High |
| Franchise Onboarding | Provision new franchisee tenant in < 4 hours | High |
| Compliance Coverage | Meet all listed regulatory standards simultaneously | Critical |
| Real-time Fraud Prevention | Sub-200ms fraud scoring at the POS | High |
| Total Cost of Ownership | Minimize per-transaction cloud cost; leverage edge compute | Medium |

---

---

# PAGE 2 — PHASE A: ARCHITECTURE VISION

---

## 2.1 Problem Statement

Global enterprise retailers operating a franchise model face a fundamental architectural tension:

1. **Centralization vs. Autonomy:** HQ needs unified visibility, governance, and AI capability. Franchisees need independence, data isolation, and local performance.
2. **Connectivity vs. Resilience:** Cloud-native platforms break when connectivity drops. Stores cannot stop trading because of a WAN outage.
3. **Scale vs. Compliance:** Operating across 40+ countries means 40+ overlapping data residency, payment, and privacy obligations.
4. **AI aspiration vs. Edge reality:** AI use cases require data and compute, but stores operate on constrained hardware with intermittent internet.

This architecture resolves all four tensions through a structured, layered platform built on Azure.

---

## 2.2 Architecture Vision Statement

> **"A globally distributed, AI-native retail POS platform where every franchisee operates with full autonomy and data isolation, every store trades continuously regardless of connectivity, and every customer interaction is intelligently enhanced — all governed within a unified HQ policy framework."**

---

## 2.3 Capability Target Summary

```
┌──────────────────────────────────────────────────────────────────┐
│                    CAPABILITY TARGET MAP                         │
├─────────────────────┬────────────────┬───────────────────────────┤
│ Capability Domain   │ Current State  │ Target State              │
├─────────────────────┼────────────────┼───────────────────────────┤
│ POS Operations      │ Siloed, legacy │ Unified, AI-assisted POS  │
│ Offline Mode        │ Manual/paper   │ Fully automated edge sync │
│ Fraud Detection     │ Rule-based     │ Real-time ML at POS edge  │
│ Demand Forecasting  │ Spreadsheets   │ Azure ML forecasting      │
│ Customer Loyalty    │ Generic promos │ Hyper-personalised AI     │
│ Self-checkout       │ None / basic   │ CV-powered self-checkout  │
│ Store Assistant     │ None           │ Azure OpenAI NLP chatbot  │
│ POS Maintenance     │ Reactive       │ Predictive AI alerts      │
│ Tenant Management   │ Manual         │ Automated provisioning    │
│ Compliance          │ Partial, manual│ Automated, continuous     │
└─────────────────────┴────────────────┴───────────────────────────┘
```

---

## 2.4 Key Architectural Decisions (KADs)

| KAD ID | Decision | Rationale |
|---|---|---|
| KAD-001 | Azure as primary cloud | Azure OpenAI, IoT Edge, AKS integration; existing enterprise agreements |
| KAD-002 | Schema-per-tenant on Azure SQL/PostgreSQL Flexible | Strong isolation; regulatory compliance; no cross-tenant risk |
| KAD-003 | Event sourcing with Azure Event Hubs | Offline event queuing; replay capability; audit trail |
| KAD-004 | K3s/AKS Edge at store level | Containerized store apps; consistent deployment via GitOps |
| KAD-005 | Azure IoT Edge for AI model deployment | OTA model updates to store edge; centralized MLOps |
| KAD-006 | Offline-first with CRDTs + event queue | Deterministic conflict resolution; no data loss |
| KAD-007 | Azure OpenAI GPT-4o for NLP assistant | Enterprise-grade, GDPR-compliant hosted model |
| KAD-008 | PCI-DSS P2PE at POS terminal | Payment data never in plaintext on POS application layer |

---

---

# PAGE 3 — PHASE B: BUSINESS ARCHITECTURE

---

## 3.1 Operating Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        GLOBAL OPERATING MODEL                          │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    CORPORATE HQ (Platform Owner)                 │  │
│  │  Strategy │ Platform Engineering │ AI/ML │ Compliance │ Finance  │  │
│  └──────────────────────────────┬───────────────────────────────────┘  │
│                                 │ Policy, Platform, AI Models          │
│          ┌──────────────────────┼──────────────────────┐              │
│          │                      │                      │              │
│  ┌───────▼──────┐    ┌──────────▼──────┐    ┌─────────▼──────┐       │
│  │  APAC Region │    │  EMEA Region    │    │ Americas Region │       │
│  │ Franchisees  │    │  Franchisees    │    │  Franchisees   │       │
│  └───────┬──────┘    └──────────┬──────┘    └─────────┬──────┘       │
│          │                      │                      │              │
│  ┌───────▼──────┐    ┌──────────▼──────┐    ┌─────────▼──────┐       │
│  │ Store Cluster│    │  Store Cluster  │    │  Store Cluster │       │
│  │ (Edge Nodes) │    │  (Edge Nodes)   │    │  (Edge Nodes)  │       │
│  └───────┬──────┘    └──────────┬──────┘    └─────────┬──────┘       │
│          │                      │                      │              │
│  ┌───────▼──────────────────────▼──────────────────────▼──────┐       │
│  │                   POS Terminals (Edge Devices)              │       │
│  └─────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3.2 Business Capability Map (Level 1 & 2)

```
┌────────────────────────────────────────────────────────────────────┐
│                  BUSINESS CAPABILITY MAP                           │
├──────────────────┬──────────────────┬───────────────┬─────────────┤
│ SELL             │ STOCK            │ SERVE         │ GOVERN      │
├──────────────────┼──────────────────┼───────────────┼─────────────┤
│ POS Transaction  │ Inventory Mgmt   │ Customer 360  │ Tenant Mgmt │
│ Self-Checkout    │ Demand Forecast  │ Loyalty Prog. │ Compliance  │
│ Returns/Exchange │ Replenishment    │ Personalistn  │ Audit/Risk  │
│ Promotions       │ Warehouse Sync   │ NLP Assistant │ Reporting   │
│ Multi-currency   │ Shrinkage Det.   │ Complaints    │ Finance     │
├──────────────────┼──────────────────┼───────────────┼─────────────┤
│ PAY              │ OPERATE          │ PROTECT       │ LEARN       │
├──────────────────┼──────────────────┼───────────────┼─────────────┤
│ Card/NFC/QR      │ Staff Scheduling │ Fraud Detect  │ AI/ML       │
│ Split Payments   │ POS Maintenance  │ Data Privacy  │ Analytics   │
│ Offline Payment  │ Store Ops        │ Cybersecurity │ BI/Reports  │
│ Reconciliation   │ Energy Mgmt      │ Compliance    │ Forecasting │
└──────────────────┴──────────────────┴───────────────┴─────────────┘
```

---

## 3.3 Franchise Hierarchy & Responsibility Matrix

| Capability | Corporate HQ | Regional Admin | Franchisee | Store Manager |
|---|---|---|---|---|
| Platform Engineering | **Own** | Consume | Consume | — |
| AI Model Training | **Own** | Input Data | Input Data | — |
| Compliance Policy | **Own** | Enforce | Comply | Comply |
| Tenant Configuration | Define Bounds | Supervise | **Own** | — |
| Product Catalogue | **Own** (master) | Regional overlay | Local overlay | — |
| Pricing & Promotions | Define rules | Regional rules | **Own** (within rules) | Approve |
| POS Operations | Policy | Monitor | **Own** | Execute |
| Staff Management | Policy | — | **Own** | Execute |
| Local Reporting | — | View | **Own** | View |
| Data Residency | **Mandate** | Enforce | Comply | — |

---

## 3.4 Core Value Streams

### VS1: Customer Purchase Transaction
```
Enter Store → Browse/Scan → Add to Basket → Apply Promotions
→ Payment → Receipt → Loyalty Update → Inventory Update → Sync to Cloud
```

### VS2: Store Offline Recovery
```
Connectivity Lost → POS Continues (edge mode) → Transactions Queued
→ Connectivity Restored → Event Replay → Conflict Resolution
→ Cloud Sync → Reconciliation Confirmed
```

### VS3: Franchisee Onboarding
```
HQ Approval → Tenant Schema Provisioned → Configuration Seeded
→ AI Models Deployed to Edge → Staff Trained → Go-Live
```

### VS4: AI-Driven Replenishment
```
Sales Data Captured → Aggregated at Store Edge → Synced to Azure ML
→ Demand Forecast Generated → Purchase Order Raised
→ Approval Workflow → Supplier Integration
```

---

## 3.5 Business Process: POS Transaction (Online & Offline)

```
┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
│  SCAN    │   │  APPLY   │   │  FRAUD   │   │  PAYMENT │   │  CLOSE   │
│  ITEMS   ├──►│  PROMOS  ├──►│  CHECK   ├──►│  PROCESS ├──►│TRANSACTION│
│          │   │  + AI    │   │  (Edge)  │   │          │   │+ RECEIPT │
└──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘
     │                                              │               │
     │ [Offline]                        [Offline]  │               │
     ▼                                             ▼               ▼
Local SQLite                              Tokenised offline   Queue for
cache                                     payment stored      cloud sync
```

---

---

# PAGE 4 — PHASE C: APPLICATION ARCHITECTURE

---

## 4.1 Application Portfolio Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     APPLICATION LANDSCAPE                               │
├──────────────────────────────────────────────────────────────────────────┤
│  EDGE TIER (POS Terminal)          STORE TIER (Edge Server)             │
│  ┌─────────────────────────┐       ┌──────────────────────────────┐    │
│  │  POS Application        │       │  Store Edge Platform (K3s)   │    │
│  │  ├ Transaction Engine   │◄─────►│  ├ Store Orchestration API   │    │
│  │  ├ Offline Sync Agent   │       │  ├ Local AI Inference Engine  │    │
│  │  ├ AI Fraud Module      │       │  ├ Inventory Service          │    │
│  │  ├ Promo Engine (local) │       │  ├ Loyalty Service            │    │
│  │  ├ Receipt Service      │       │  ├ CV Self-Checkout Service   │    │
│  │  ├ Payment Terminal API │       │  ├ NLP Store Assistant        │    │
│  │  └ Local SQLite/PG DB   │       │  ├ Sync Manager               │    │
│  └─────────────────────────┘       │  └ Local PostgreSQL DB        │    │
│                                    └──────────────────────────────┘    │
├──────────────────────────────────────────────────────────────────────────┤
│  CLOUD TIER (Azure AKS — per tenant namespace)                          │
│  ┌─────────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────┐  │
│  │ API Gateway │ │Tenant   │ │Inventory│ │ Loyalty │ │   Payment   │  │
│  │(APIM)       │ │ Mgmt    │ │ Service │ │ Service │ │  Service    │  │
│  └─────────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────────┘  │
│  ┌─────────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────┐  │
│  │  Reporting  │ │   AI    │ │  Order  │ │ Product │ │  Notif.     │  │
│  │  & BI Svc.  │ │Platform │ │ Service │ │Catalogue│ │  Service    │  │
│  └─────────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────────┘  │
├──────────────────────────────────────────────────────────────────────────┤
│  PLATFORM SERVICES (Shared, HQ-managed)                                 │
│  Azure Event Hubs │ Azure Service Bus │ Azure API Management            │
│  Azure OpenAI     │ Azure ML          │ Azure IoT Hub                   │
│  Azure Active Directory B2C │ Key Vault │ Monitor / Sentinel            │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 4.2 POS Application — Component Design

### 4.2.1 Core Modules

| Module | Technology | Offline Capable | AI-Enhanced |
|---|---|---|---|
| Transaction Engine | .NET 8 / Java 21 | ✅ Full | ✅ Promotion AI |
| Payment Handler | C++ / Verifone SDK | ✅ Tokenised offline | ✅ Fraud scoring |
| Offline Sync Agent | Rust (reliability) | ✅ Native | — |
| Local DB | SQLite (POS) / PostgreSQL (Store Edge) | ✅ Always | — |
| AI Fraud Module | ONNX Runtime (edge) | ✅ Local inference | ✅ Real-time ML |
| Promo Engine | .NET 8 | ✅ Cached rules | ✅ Personalised AI |
| NLP Assistant | Azure OpenAI (online) / SLM offline | Partial | ✅ GPT-4o |
| Self-Checkout CV | Azure Custom Vision / ONNX | ✅ Edge inference | ✅ CV model |
| Receipt Service | .NET 8 | ✅ Local print | — |
| Predictive Maintenance | Azure IoT Edge module | ✅ Edge model | ✅ Anomaly detect |

---

### 4.2.2 Offline Mode State Machine

```
                    ┌──────────────────────────┐
                    │     ONLINE (NORMAL)       │
                    │ Full sync │ Real-time AI  │
                    └──────────┬───────────────┘
                               │ Connectivity Lost
                               ▼
                    ┌──────────────────────────┐
                    │   DEGRADED ONLINE        │◄──── Reconnecting
                    │ Buffering events         │
                    └──────────┬───────────────┘
                               │ Sync timeout (30s)
                               ▼
                    ┌──────────────────────────┐
                    │   POS OFFLINE MODE       │
                    │ Local DB only            │
                    │ Offline AI (ONNX)        │
                    │ Payment tokenised        │
                    │ Events queued            │
                    └──────────┬───────────────┘
                               │ Connectivity Restored
                               ▼
                    ┌──────────────────────────┐
                    │   SYNC RECOVERY          │
                    │ Event replay             │
                    │ Conflict resolution      │
                    │ Reconciliation           │
                    └──────────┬───────────────┘
                               │ Sync confirmed
                               ▼
                    ┌──────────────────────────┐
                    │     ONLINE (NORMAL)       │
                    └──────────────────────────┘
```

---

## 4.3 Application Integration Map

```
POS Terminal ──── HTTPS/MQTT ──── Store Edge Server
                                        │
                                 Azure IoT Hub
                                        │
                               ┌────────▼─────────┐
                               │  API Management  │
                               │   (Azure APIM)   │
                               └────────┬─────────┘
                    ┌───────────────────┼───────────────────┐
                    │                   │                   │
             ┌──────▼──────┐   ┌───────▼──────┐   ┌───────▼──────┐
             │  Tenant API │   │  AI Platform │   │  Event Hub   │
             │  (per ns)   │   │  (Azure ML)  │   │  (per tenant)│
             └──────┬──────┘   └───────┬──────┘   └───────┬──────┘
                    │                   │                   │
             ┌──────▼──────────────────▼───────────────────▼──────┐
             │         Azure SQL / PostgreSQL Flexible             │
             │              (schema per franchisee)                │
             └─────────────────────────────────────────────────────┘
```

---

---

# PAGE 5 — PHASE C: DATA ARCHITECTURE

---

## 5.1 Data Domain Model

### Core Data Domains

| Domain | Owner | Sensitivity | Residency Constraint | Storage |
|---|---|---|---|---|
| Transaction | Franchisee | PCI-DSS (Card) | Local jurisdiction | Azure SQL (tenant schema) |
| Customer PII | Franchisee | GDPR/CCPA/DPDP | Country of customer | Encrypted Azure SQL |
| Product Catalogue | HQ (shared) | Low | None | Azure CosmosDB (global) |
| Inventory | Franchisee | Medium | Regional | Azure SQL (tenant schema) |
| AI Training Data | HQ/Franchisee | High | Data Processing Agreement | Azure Data Lake Gen2 |
| Loyalty | Franchisee | GDPR | Country of customer | Azure SQL (tenant schema) |
| Audit Logs | HQ (immutable) | Compliance | Per regulation | Azure Immutable Blob |
| POS Telemetry | HQ | Low-Medium | None | Azure IoT Hub + ADX |
| Financial | Franchisee | High | Jurisdiction | Azure SQL (tenant schema) |

---

## 5.2 Schema-per-Tenant Design

```
┌─────────────────────────────────────────────────────────────────────────┐
│          AZURE SQL / POSTGRESQL FLEXIBLE — SCHEMA ISOLATION            │
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │
│  │ schema:         │  │ schema:         │  │ schema:         │        │
│  │ franchisee_001  │  │ franchisee_002  │  │ franchisee_N    │        │
│  │                 │  │                 │  │                 │        │
│  │ transactions    │  │ transactions    │  │ transactions    │        │
│  │ customers       │  │ customers       │  │ customers       │        │
│  │ inventory       │  │ inventory       │  │ inventory       │        │
│  │ loyalty         │  │ loyalty         │  │ loyalty         │        │
│  │ audit_log       │  │ audit_log       │  │ audit_log       │        │
│  │ pos_config      │  │ pos_config      │  │ pos_config      │        │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘        │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  schema: platform_shared (HQ only — read-only to franchisees)    │  │
│  │  product_catalogue │ promotions_engine │ ai_model_registry       │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  Row-Level Security enforced at DB connection string level              │
│  No cross-schema JOINs permitted at application layer                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Tenant Isolation Enforcement Points

1. **Connection Level:** Separate DB users per tenant; credentials from Azure Key Vault per tenant.
2. **Application Level:** TenantContext middleware injects schema name into every ORM query.
3. **API Level:** JWT token contains `tenant_id`; APIM policy blocks mismatched schema access.
4. **Network Level:** Azure Private Endpoints per tenant DB server (VNET injection).
5. **Audit Level:** Every query logged with `tenant_id` to immutable audit store.

---

## 5.3 Offline Data Sync Architecture

### Synchronization Strategy: Event Sourcing + CRDT

```
┌─────────────────┐                    ┌──────────────────────┐
│  POS Terminal   │                    │  Azure Event Hubs    │
│  Local SQLite   │                    │  (per-tenant topic)  │
│                 │                    │                      │
│  ┌───────────┐  │   MQTT/HTTPS       │  ┌────────────────┐  │
│  │ Event Log │  ├──────────────────► │  │  Event Stream  │  │
│  │ (append   │  │  (on reconnect)    │  │  (ordered,     │  │
│  │  only)    │  │                    │  │   partitioned) │  │
│  └───────────┘  │                    │  └───────┬────────┘  │
└─────────────────┘                    └──────────┼───────────┘
                                                  │
                                       ┌──────────▼───────────┐
                                       │  Azure Stream        │
                                       │  Analytics           │
                                       │  (de-duplication,    │
                                       │   ordering,          │
                                       │   CRDT merge)        │
                                       └──────────┬───────────┘
                                                  │
                                       ┌──────────▼───────────┐
                                       │  Azure SQL           │
                                       │  (tenant schema)     │
                                       │  Canonical store     │
                                       └──────────────────────┘
```

### Conflict Resolution Rules (CRDT-based)

| Conflict Type | Resolution Strategy |
|---|---|
| Inventory count | Last-write-wins with timestamp vector clock |
| Transaction (completed) | Immutable — never overwritten |
| Customer loyalty points | Additive CRDT (G-Counter) |
| Price at time of sale | Captured at POS — immutable |
| Promotion applied | Captured at POS — audit logged |
| Refund processed offline | Held pending online verification |

---

## 5.4 Data Flow Diagram — Full Lifecycle

```
[Customer Scan] ──► [POS Local SQLite] ──► [Store Edge PG]
                                                │
                                                ▼
                                     [Azure Event Hubs]
                                                │
                           ┌────────────────────┼──────────────────────┐
                           │                    │                      │
                    [Stream Analytics]    [Azure ML]           [Data Lake Gen2]
                    (real-time CRDT)     (AI training)         (long-term store)
                           │                    │                      │
                    [Tenant SQL Schema]   [Model Registry]    [Power BI / Synapse]
```

---

## 5.5 Master Data Management

| Master Data Entity | Golden Record Owner | Distribution Method | Offline Cache |
|---|---|---|---|
| Product (SKU, barcode) | HQ Platform | CosmosDB global replication | Full copy on store edge |
| Pricing Rules | HQ + Franchisee | Azure Service Bus push | Full copy on POS |
| Promotion Rules | HQ + Franchisee | Service Bus push + IoT Edge | Full copy on POS |
| Tax Tables | HQ (per jurisdiction) | Config service | Full copy on POS |
| Customer Profile | Franchisee (GDPR-scoped) | Event-driven CDC | Hash-only on POS |
| Staff / Users | Franchisee | LDAP/AAD B2C sync | Hashed credentials local |
| Currency Rates | HQ (FX service) | Scheduled push (15 min) | Last-known fallback |

---

---

# PAGE 6 — PHASE D: TECHNOLOGY ARCHITECTURE

---

## 6.1 Azure Reference Architecture — Full Stack

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AZURE GLOBAL PLATFORM                              │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  Azure Front Door (Global Load Balancer + WAF + CDN)               │  │
│  └──────────────────────────────────┬───────────────────────────────────┘  │
│                                     │                                       │
│  ┌──────────────────────────────────▼───────────────────────────────────┐  │
│  │  Azure API Management (APIM) — Multi-region, per-tenant policies   │  │
│  └──────────────────────────────────┬───────────────────────────────────┘  │
│                                     │                                       │
│  ┌──────────────────────────────────▼───────────────────────────────────┐  │
│  │  Azure Kubernetes Service (AKS) — Multi-cluster                    │  │
│  │                                                                      │  │
│  │  Namespace: franchisee-001  │  Namespace: franchisee-002  │  ...   │  │
│  │  ┌─────────────────────┐    │  ┌─────────────────────┐            │  │
│  │  │ POS API Service     │    │  │ POS API Service     │            │  │
│  │  │ Inventory Service   │    │  │ Inventory Service   │            │  │
│  │  │ Loyalty Service     │    │  │ Loyalty Service     │            │  │
│  │  │ AI Inference Proxy  │    │  │ AI Inference Proxy  │            │  │
│  │  │ Sync Service        │    │  │ Sync Service        │            │  │
│  │  └─────────────────────┘    │  └─────────────────────┘            │  │
│  │                                                                      │  │
│  │  Namespace: platform-shared (HQ only)                              │  │
│  │  ┌─────────────────────────────────────────────────────────────┐   │  │
│  │  │ Tenant Mgmt │ AI Platform │ Compliance │ Reporting │ Auth  │   │  │
│  │  └─────────────────────────────────────────────────────────────┘   │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────────────┐   │
│  │ Azure SQL  │  │ Cosmos DB  │  │ Azure ML   │  │ Azure OpenAI       │   │
│  │ Flexible   │  │ (catalogue)│  │ Workspace  │  │ GPT-4o + Embeddings│   │
│  │ (per tenant│  │            │  │            │  │                    │   │
│  │  schema)   │  │            │  │            │  │                    │   │
│  └────────────┘  └────────────┘  └────────────┘  └────────────────────┘   │
│                                                                             │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────────────┐   │
│  │ Event Hubs │  │ Service Bus│  │  Key Vault │  │ Azure Monitor +    │   │
│  │ (streaming)│  │ (commands) │  │ (per tenant│  │ Sentinel + Defender│   │
│  │            │  │            │  │  secrets)  │  │                    │   │
│  └────────────┘  └────────────┘  └────────────┘  └────────────────────┘   │
│                                                                             │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────────────┐   │
│  │ IoT Hub    │  │ Data Lake  │  │ Synapse    │  │ Azure AD B2C +     │   │
│  │ (edge mgmt)│  │ Gen2       │  │ Analytics  │  │ AAD (staff)        │   │
│  └────────────┘  └────────────┘  └────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 6.2 Store Edge Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    STORE EDGE NODE                              │
│           (Industrial PC / NUC — Linux / Windows Server)       │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              K3s (Lightweight Kubernetes)                 │  │
│  │                                                           │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │  │
│  │  │Store Orch API│  │Local AI Eng. │  │ Sync Manager   │  │  │
│  │  │(REST/gRPC)   │  │(ONNX Runtime)│  │(Event Queue)   │  │  │
│  │  └──────────────┘  └──────────────┘  └────────────────┘  │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │  │
│  │  │ Inventory Svc│  │ CV Service   │  │ NLP SLM Module │  │  │
│  │  │ (local)      │  │ (Camera feed)│  │ (Phi-3 offline)│  │  │
│  │  └──────────────┘  └──────────────┘  └────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │  PostgreSQL (store-level canonical DB)               │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │           Azure IoT Edge Runtime                         │  │
│  │  AI Model Modules deployed via Azure IoT Hub             │  │
│  │  OTA updates │ Module health monitoring │ Telemetry      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │ POS Terminal │  │ POS Terminal │  │ Self-Checkout Kiosk│   │
│  │ (Windows/.NET│  │ (Android/APK)│  │ (Linux + CV)       │   │
│  └──────────────┘  └──────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
               │
               │ TLS 1.3 over WAN (primary) / 4G/5G (failover)
               │
        [Azure IoT Hub / Event Hubs]
```

---

## 6.3 Network Topology

### Connectivity Tiers

| Tier | Primary | Failover | Offline Capable |
|---|---|---|---|
| POS to Store Edge | LAN (Ethernet/WiFi) | Local WiFi | ✅ Always |
| Store Edge to Azure | MPLS / Broadband | 4G/5G SIM | ✅ Store Edge buffers |
| Azure inter-region | Azure ExpressRoute / Premium backbone | Internet gateway | ✅ Azure native |
| Franchisee Admin to Azure | Azure VPN Gateway | HTTPS web | ✅ Read-only offline |

### Port & Protocol Map

| Flow | Protocol | Port | Encryption |
|---|---|---|---|
| POS ↔ Store Edge | HTTPS / MQTT | 443 / 8883 | TLS 1.3 |
| Store Edge ↔ IoT Hub | AMQP / MQTT | 5671 / 8883 | TLS 1.3 + X.509 |
| AKS ↔ Azure SQL | TDS over TLS | 1433 | TLS 1.3 |
| AKS ↔ Event Hubs | AMQP | 5671 | TLS 1.3 |
| APIM ↔ AKS | HTTPS | 443 | mTLS |
| Admin Portal ↔ APIM | HTTPS | 443 | TLS 1.3 + AAD |

---

## 6.4 DevOps / MLOps Platform

```
┌───────────────────────────────────────────────────────────────┐
│                  CI/CD + MLOps PIPELINE                       │
│                                                               │
│  Git (Azure DevOps Repos)                                     │
│         │                                                     │
│         ▼                                                     │
│  Azure Pipelines (CI)                                         │
│  ├ Unit Tests │ SAST (Checkmarx) │ Container Scan (Trivy)    │
│  └ IaC lint (Bicep/Terraform) │ Dependency audit             │
│         │                                                     │
│         ▼                                                     │
│  Azure Container Registry (ACR)                              │
│  (signed images, per-env tags)                                │
│         │                                                     │
│         ▼                                                     │
│  GitOps (Flux v2 on AKS)                                      │
│  ├ Dev → Staging → Production clusters                        │
│  └ Store Edge deployment via IoT Hub + Flux                   │
│         │                                                     │
│         ▼                                                     │
│  Azure ML Pipelines (MLOps)                                   │
│  ├ Data prep → Feature engineering → Train → Evaluate         │
│  ├ Model Registry (versioned) → A/B test → Approve           │
│  └ Deploy to: AKS inference | IoT Edge | POS ONNX bundle      │
└───────────────────────────────────────────────────────────────┘
```

---

---

# PAGE 7 — AI ENGINEERING ARCHITECTURE

---

## 7.1 AI Platform Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AI ENGINEERING PLATFORM                        │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    AZURE AI FOUNDATION LAYER                     │  │
│  │  Azure OpenAI (GPT-4o, Ada-002 Embeddings, Whisper)              │  │
│  │  Azure Machine Learning (AutoML, Custom Models, Pipelines)       │  │
│  │  Azure AI Services (Custom Vision, Form Recogniser, Translator)  │  │
│  │  Azure AI Search (vector + semantic)                              │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │                  AI USE CASE PORTFOLIO                        │     │
│  │  UC1: Demand Forecasting    UC2: Fraud Detection              │     │
│  │  UC3: Personalised Promos   UC4: Computer Vision              │     │
│  │  UC5: NLP Store Assistant   UC6: Predictive Maintenance       │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │                   AI DEPLOYMENT TIERS                         │     │
│  │  Cloud (AKS)    │  Store Edge (IoT Edge / K3s)  │  POS (ONNX) │     │
│  │  Full models    │  Quantised / distilled         │  Tiny models│     │
│  │  Batch + real-  │  ONNX Runtime optimised        │  <50ms infer│     │
│  │  time inference │  GPU optional (NVIDIA Jetson)  │             │     │
│  └────────────────────────────────────────────────────────────────┘     │
│                                                                         │
│  ┌────────────────────────────────────────────────────────────────┐     │
│  │                  MLOps GOVERNANCE                             │     │
│  │  Model Registry (versioned) │ Drift monitoring (Evidently AI) │     │
│  │  Explainability (SHAP/LIME) │ Bias detection (Fairlearn)      │     │
│  │  A/B testing (traffic split)│ Rollback automation             │     │
│  │  Audit trail (immutable log)│ Model cards (per regulation)    │     │
│  └────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 7.2 UC1 — AI-Driven Demand Forecasting & Replenishment

### Architecture

```
[POS Transaction Events] ──► [Event Hubs] ──► [Azure Data Lake Gen2]
                                                       │
                                              [Azure ML Feature Store]
                                              Features:
                                              - Sales velocity (7/14/30d)
                                              - Seasonality indices
                                              - Weather API correlation
                                              - Promotional calendar
                                              - External events (holidays)
                                                       │
                                              [Azure ML Training Pipeline]
                                              Model: Temporal Fusion
                                              Transformer (TFT) per SKU
                                              Horizon: 7/14/30 day forecast
                                                       │
                                              [Azure ML Managed Endpoint]
                                              ├ Per-tenant inference
                                              └ Per-store SKU forecasts
                                                       │
                                              [Replenishment Service (AKS)]
                                              ├ Generate PO suggestions
                                              ├ Alert: low stock risk
                                              └ Push to ERP / WMS
```

### Key Specifications

| Attribute | Specification |
|---|---|
| Model type | Temporal Fusion Transformer (TFT) + Prophet ensemble |
| Training frequency | Daily (incremental), Full retrain weekly |
| Inference scope | Per franchisee, per store, per SKU |
| Forecast horizon | 7, 14, 30 days |
| Latency | Batch (nightly); on-demand < 5 seconds |
| Tenant isolation | Separate feature store partition per franchisee |
| Explainability | Feature importance scores returned with forecast |

---

## 7.3 UC2 — Real-Time Fraud & Anomaly Detection at POS

### Architecture

```
POS Transaction Event ──► Fraud Scoring Engine
                                │
               ┌────────────────┼────────────────────────┐
               │                │                        │
    [ONNX model on POS]  [Store Edge ML]          [Cloud Azure ML]
    <50ms local          <200ms edge              Batch retrospective
    Pre-computed rules   Behavioural model        Deep pattern mining
    Velocity checks      Contextual scoring       Cross-tenant signals
               │                │                        │
               └────────────────▼────────────────────────┘
                       FRAUD DECISION ENGINE
                       ┌──────────────────────────────┐
                       │ Score 0.0–1.0               │
                       │ 0.0–0.4: Allow              │
                       │ 0.4–0.7: Step-up auth       │
                       │ 0.7–1.0: Decline + Alert    │
                       └──────────────────────────────┘
                                    │
                        [Alert Service → Store Manager]
                        [Event logged to Audit Hub]
```

### Fraud Feature Vector

| Feature Category | Features |
|---|---|
| Transaction | Amount, currency, item count, discount %, time of day |
| Behavioural | Transaction frequency, velocity (1h/24h), return rate |
| Device | POS ID, firmware version, location delta |
| Card/Payment | BIN country, card type, contactless flag, offline indicator |
| Contextual | Store type, staff ID, shift pattern, new vs. returning customer |

### Model Specifications

| Layer | Model | Inference Location | Latency Target |
|---|---|---|---|
| POS Local | Gradient Boosting (LightGBM) — ONNX | POS device | < 50ms |
| Store Edge | Neural network anomaly detector | Store Edge | < 200ms |
| Cloud | Isolation Forest + Graph Neural Network | Azure ML | Async (batch) |

---

## 7.4 UC3 — AI-Powered Personalised Promotions & Loyalty

### Architecture

```
Customer Identified (loyalty card / QR / face-opt-in)
            │
  [Customer Embedding Service]
  Azure AI Search (vector store)
  Customer profile + purchase history vector
            │
  [Recommendation Engine (AKS)]
  Collaborative Filtering + Contextual Bandits
  Real-time context: basket, time, weather, stock
            │
  [Promotion Resolver]
  HQ rules + Franchisee overrides + AI score
  Ranking: personalization score × margin impact
            │
  [POS Promo Display] ──► Cashier screen / customer-facing screen
            │
  [Outcome Capture]
  Accepted / declined / modified → reward signal
            │
  [Reinforcement Learning loop back to Azure ML]
```

### GDPR / CCPA Personalisation Consent Flow

```
First Visit: Explicit opt-in prompt on POS screen
│
├── Consent YES → Full personalisation, stored with timestamp
├── Consent NO  → Anonymous segment-only promos (no individual tracking)
└── Consent WITHDRAW → Immediate erasure pipeline triggered (24h SLA)
```

---

## 7.5 UC4 — Computer Vision: Self-Checkout & Shelf Analytics

### Self-Checkout CV Pipeline

```
Camera Feed ──► Azure Custom Vision (ONNX, store edge)
                        │
              Item Detection + Classification
              (trained on SKU images per franchisee)
                        │
              ┌─────────▼──────────┐
              │  Match to product   │
              │  catalogue          │
              │  Confidence ≥ 0.92 │ ──► Auto-add to basket
              │  Confidence < 0.92 │ ──► Request manual scan
              └─────────────────────┘
                        │
              Weight verification (IoT scale integration)
                        │
              Anti-theft signal: unscanned item detection
```

### Shelf Analytics Pipeline

```
Overhead/shelf cameras ──► Azure IoT Edge CV module
                                    │
                          Planogram compliance check
                          Out-of-stock detection
                          Misplaced item detection
                                    │
                          [Store Manager App Alert]
                          [Inventory Service trigger]
```

### Model Specifications

| Model | Type | Training | Inference Location | Update Mechanism |
|---|---|---|---|---|
| Item recognition | YOLOv8 fine-tuned | Per franchisee (SKU images) | Store Edge (ONNX) | IoT Edge OTA |
| Planogram check | ResNet-50 | HQ shared + store override | Store Edge | OTA weekly |
| Anti-theft | Two-stream CNN + LSTM | HQ shared | Store Edge | OTA monthly |

---

## 7.6 UC5 — NLP-Based Store Assistant / Customer Chatbot

### Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                  STORE ASSISTANT ARCHITECTURE                   │
│                                                                  │
│  Input channels:                                                 │
│  ├ Touch kiosk (text input)                                     │
│  ├ Voice (Whisper STT → text)                                   │
│  └ Staff mobile app                                             │
│                         │                                        │
│  ┌──────────────────────▼───────────────────────────────────┐   │
│  │          INTENT CLASSIFICATION                           │   │
│  │  Azure OpenAI Ada-002 embeddings + classifier            │   │
│  │  Categories: Product search │ Price │ Stock │ Policy     │   │
│  │              Return process │ Loyalty │ Complaints       │   │
│  └──────────────────────┬───────────────────────────────────┘   │
│                         │                                        │
│  ┌──────────────────────▼───────────────────────────────────┐   │
│  │          RAG (Retrieval Augmented Generation)            │   │
│  │  Knowledge base:                                         │   │
│  │  ├ Product catalogue (CosmosDB → vector indexed)         │   │
│  │  ├ Store policies (per franchisee)                       │   │
│  │  ├ Promotions (real-time)                                │   │
│  │  └ FAQ corpus                                            │   │
│  │  Retrieval: Azure AI Search (hybrid semantic + keyword)  │   │
│  └──────────────────────┬───────────────────────────────────┘   │
│                         │                                        │
│  ┌──────────────────────▼───────────────────────────────────┐   │
│  │         GENERATION — Azure OpenAI GPT-4o                │   │
│  │  System prompt: tenant-specific, brand-voice tuned       │   │
│  │  Guardrails: Azure AI Content Safety                     │   │
│  │  Language: Auto-detected, 40+ languages supported        │   │
│  └──────────────────────┬───────────────────────────────────┘   │
│                         │                                        │
│  OFFLINE MODE: Phi-3 Mini (SLM) on store edge                   │
│  ├ Reduced capability: product search + FAQ only               │
│  └ Knowledge base cached locally (last 24h sync)               │
└──────────────────────────────────────────────────────────────────┘
```

---

## 7.7 UC6 — Predictive Maintenance for POS Hardware

### Architecture

```
POS Hardware Sensors → IoT Edge Telemetry Agent
Telemetry:
├ CPU/Memory/Disk utilisation
├ Peripheral error codes (printer, scanner, card reader)
├ Network packet loss / latency
├ Transaction throughput vs. baseline
├ Touch screen response time
└ Thermal readings
        │
[Azure IoT Hub] ──► [Azure Digital Twins]
                    (per-device asset model)
        │
[Azure ML Anomaly Detection]
├ Isolation Forest per device type
├ Rolling baseline (7-day)
└ Failure prediction: 72-hour horizon
        │
[Maintenance Alert Service (AKS)]
├ Priority: Critical / Warning / Info
├ Auto-create ticket in ITSM (ServiceNow / Jira)
├ Dispatch nearest technician
└ Pre-order replacement parts
```

### Predicted Failure Categories

| Component | Prediction Model | Lead Time | Action |
|---|---|---|---|
| Thermal printer | Roller wear curve | 7 days | Schedule maintenance |
| Barcode scanner | Error rate spike | 48 hours | Alert technician |
| Card reader | Read failure rate | 72 hours | Pre-order replacement |
| Network adapter | Packet loss trend | 24 hours | ISP incident ticket |
| Touch screen | Response latency | 5 days | Schedule replacement |
| POS PC hardware | Thermal + CPU trend | 7 days | Proactive swap |

---

---

# PAGE 8 — POS OFFLINE ARCHITECTURE

---

## 8.1 POS Offline Design Philosophy

The POS terminal operates as a **fully autonomous transaction processing node**. Cloud connectivity is treated as a performance enhancement, not a dependency. The terminal must be able to:

- Process unlimited transactions offline
- Apply correct pricing and promotions
- Score transactions for fraud
- Process payments (offline-capable modes)
- Print receipts
- Manage a shift and perform end-of-day

---

## 8.2 POS Local Data Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│              POS TERMINAL LOCAL DATA STORES                    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  SQLite (primary local store)                          │   │
│  │                                                         │   │
│  │  Tables:                                                │   │
│  │  ├ transactions (append-only, event-sourced)           │   │
│  │  ├ transaction_lines                                    │   │
│  │  ├ product_cache (full catalogue copy, compressed)     │   │
│  │  ├ price_rules (versioned, HQ-pushed)                  │   │
│  │  ├ promotion_rules (versioned, HQ-pushed)              │   │
│  │  ├ tax_rates (per jurisdiction)                        │   │
│  │  ├ staff_credentials (PBKDF2-hashed, AAD fallback)     │   │
│  │  ├ loyalty_delta (offline accruals pending sync)       │   │
│  │  ├ offline_payment_tokens (encrypted, time-limited)    │   │
│  │  ├ event_outbox (pending cloud sync events)            │   │
│  │  └ sync_state (vector clock, last-sync metadata)       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ONNX Model Store (file system — encrypted)            │   │
│  │  ├ fraud_detection_v{N}.onnx                           │   │
│  │  ├ promotion_ranker_v{N}.onnx                          │   │
│  │  └ cv_item_recognition_v{N}.onnx (self-checkout only) │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Secure Enclave (TPM / Windows Secure Enclave)         │   │
│  │  ├ Payment tokenisation keys (P2PE)                    │   │
│  │  ├ Device identity certificate (X.509)                 │   │
│  │  └ Offline payment ceiling config (signed by HQ)       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 8.3 Offline Payment Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│                  OFFLINE PAYMENT FLOW                            │
│                                                                   │
│  ONLINE mode:                                                     │
│  Card Tap/Insert ──► P2PE encrypt ──► Payment Gateway ──► Auth   │
│                                                                   │
│  OFFLINE mode:                                                    │
│  Card Tap/Insert ──► P2PE encrypt ──► Offline Token Engine        │
│                              │                                    │
│             ┌────────────────▼────────────────────┐              │
│             │         OFFLINE TOKEN ENGINE         │              │
│             │                                      │              │
│             │  Check: transaction ≤ offline limit  │              │
│             │  (HQ-signed config, tamper-proof)    │              │
│             │                                      │              │
│             │  Generate: offline payment token     │              │
│             │  (HMAC-signed, includes:             │              │
│             │   - encrypted PAN                    │              │
│             │   - amount, currency, timestamp      │              │
│             │   - POS device ID, merchant ID       │              │
│             │   - expiry: 72 hours)                │              │
│             └────────────────┬────────────────────┘              │
│                              │                                    │
│             ┌────────────────▼────────────────────┐              │
│             │        LOCAL STORAGE                 │              │
│             │  offline_payment_tokens table        │              │
│             │  (AES-256 at rest)                   │              │
│             └────────────────┬────────────────────┘              │
│                              │ On reconnect                       │
│             ┌────────────────▼────────────────────┐              │
│             │     CLOUD PAYMENT SETTLEMENT         │              │
│             │  Tokens replayed to payment gateway  │              │
│             │  Settlement within 72h guaranteed    │              │
│             └──────────────────────────────────────┘              │
│                                                                   │
│  Offline limits (HQ-configurable per franchisee):                │
│  ├ Per-transaction ceiling: configurable (e.g. USD 150)          │
│  ├ Per-shift offline payment ceiling: configurable               │
│  └ Card types: only EMV chip/contactless; no MSR offline         │
└───────────────────────────────────────────────────────────────────┘
```

---

## 8.4 Event Outbox Pattern (POS)

```
Every state-changing action at POS:
Transaction completed → event written to event_outbox table
                               │
                    ┌──────────▼──────────┐
                    │  Outbox Relay Agent │
                    │  (background thread)│
                    └──────────┬──────────┘
                               │
            ┌──────────────────┼──────────────────────┐
            │ Online           │ Reconnecting         │ Offline
            │                  │                      │
      Publish to         Buffer + retry         Keep in SQLite
      Event Hubs         (exponential)          outbox (no loss)
      immediately        backoff
            │
   Cloud acknowledges → mark event as dispatched
   Event NOT acknowledged → never deleted from outbox
```

---

## 8.5 Offline AI Behaviour

| AI Capability | Online Behaviour | Offline Behaviour | Degradation |
|---|---|---|---|
| Fraud scoring | Full neural model (cloud + edge) | ONNX LightGBM on POS | Reduced feature set; higher FP rate |
| Personalised promos | Real-time recommendation (cloud) | Cached segment-based rules | Static promos; no 1:1 personalisation |
| NLP assistant | GPT-4o (cloud) | Phi-3 Mini (edge SLM) | FAQ + product search only |
| CV self-checkout | Full YOLOv8 | ONNX quantised (store edge) | Slightly lower accuracy |
| Demand forecast | Real-time pull from Azure ML | Last synced forecast | Stale by 24h max |
| Predictive maintenance | Live telemetry streaming | Local anomaly detection | Alert delay up to 1h |

---

---

# PAGE 9 — STORE OFFLINE ARCHITECTURE

---

## 9.1 Store Offline Levels

```
LEVEL 0: FULLY ONLINE
All POS terminals connected to Store Edge
Store Edge connected to Azure Cloud
Full AI capabilities, real-time sync, live fraud scoring

LEVEL 1: CLOUD DISCONNECTED (Store Edge intact)
POS terminals → Store Edge: OPERATIONAL
Store Edge → Azure: DISCONNECTED
│
├── All POS transactions processed via store edge
├── Store-level AI models continue (IoT Edge modules)
├── Event queue accumulates at store edge (Event Hubs Kafka compat.)
├── Staff admin functions: read-only after cache refresh
└── Auto-recovery: when cloud reconnects, event replay triggers

LEVEL 2: STORE EDGE FAILURE (POS-only mode)
POS terminals: standalone operation
Store Edge: DOWN
│
├── POS terminals fall back to POS-local mode (Page 8)
├── Transactions stored in POS SQLite
├── No cross-POS inventory sync (last-known cached)
├── Offline payments processed per Page 8 policy
└── Auto-recovery: store edge restart → POS sync → cloud sync

LEVEL 3: TOTAL STORE ISOLATION
No connectivity: POS-only, manual reconciliation
Business continuity: 72-hour autonomous operation guaranteed
```

---

## 9.2 Store Edge High Availability

```
┌─────────────────────────────────────────────────────────────────┐
│              STORE EDGE HA CONFIGURATION                       │
│                                                                 │
│  PRIMARY EDGE NODE (active)                                     │
│  ├ K3s master + worker                                          │
│  ├ PostgreSQL primary                                           │
│  └ Azure IoT Edge runtime                                       │
│           │ Replication (synchronous)                           │
│  SECONDARY EDGE NODE (warm standby — optional per store tier)   │
│  ├ K3s worker                                                   │
│  ├ PostgreSQL replica (streaming replication)                   │
│  └ Azure IoT Edge runtime                                       │
│           │ Failover: < 30 seconds (Keepalived + Patroni)       │
│                                                                 │
│  Single-node stores: No HA; rely on POS-local fallback          │
│  Tier A stores (flagship): Active-warm HA pair                  │
│  Tier B stores (standard): Single node + POS offline fallback   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9.3 Store-to-Cloud Sync Architecture

### Sync Topology

```
POS Terminal (SQLite events)
        │ LAN
        ▼
Store Edge Server (PostgreSQL + Event Queue)
        │
  ┌─────▼──────────────────────────────────────┐
  │ STORE SYNC MANAGER (K3s pod)               │
  │                                             │
  │ Event Collector:                            │
  │ ├ Receives events from all POS terminals    │
  │ ├ Deduplicates (idempotency key)            │
  │ ├ Orders by vector clock                   │
  │ └ Writes to local Event Hub (Kafka-compat.) │
  │                                             │
  │ Cloud Forwarder:                            │
  │ ├ Reads from local queue                   │
  │ ├ Compresses (zstd, ~10:1 for tx events)   │
  │ ├ Encrypts (AES-256 + tenant key)           │
  │ ├ Publishes to Azure Event Hubs             │
  │ └ Tracks ACK → marks forwarded             │
  │                                             │
  │ Sync State:                                 │
  │ ├ Vector clock per POS terminal            │
  │ ├ Last-ACK-ed event ID per topic           │
  │ └ Sync health metrics → Azure Monitor      │
  └─────────────────────────────────────────────┘
        │ TLS 1.3 + Device certificate
        ▼
Azure Event Hubs (per-tenant topic)
        │
Azure Stream Analytics (CRDT merge, dedup)
        │
Azure SQL (tenant schema canonical store)
```

---

## 9.4 Store Offline Recovery Sequence

```
T+0:00  Connectivity Lost
        Store Edge detects IoT Hub ping timeout (30s)
        Enters OFFLINE mode; logs transition event

T+0:30  POS terminals notified (LAN broadcast)
        POS screens show "Store Mode: Offline"
        All new transactions routed to local store edge queue only

T+0:30 – T+??  Autonomous Operation
        Transactions processed normally
        AI models running on IoT Edge (local)
        Events queued to store edge PostgreSQL + local Kafka

T+??:00  Connectivity Restored
        Store Edge detects IoT Hub reconnect
        Enters SYNC RECOVERY mode

T+??:01  Event Replay
        Store Sync Manager reads backlog from local queue
        Publishes to Azure Event Hubs (batched, ordered)
        Rate-limited to avoid cloud flooding (configurable, e.g. 10k events/min)

T+??:??  CRDT Merge
        Azure Stream Analytics processes events
        Conflict resolution applied (see Page 5.3)
        Tenant SQL schema updated

T+??:??  Sync Confirmed
        Store Sync Manager receives ACK for all events
        Transitions back to ONLINE mode
        Store screens updated: "Store Mode: Online"
        Reconciliation report generated (auto, PDF)
```

---

---

# PAGE 10 — MULTITENANCY ARCHITECTURE

---

## 10.1 Tenant Hierarchy Model

```
┌──────────────────────────────────────────────────────────────────┐
│                   TENANT HIERARCHY                              │
│                                                                  │
│  LEVEL 0: PLATFORM (HQ — Anthropic-style super-admin)           │
│  └── Controls: platform config, compliance, model registry      │
│                                                                  │
│  LEVEL 1: ENTERPRISE GROUP (e.g., "RetailCorp Global")          │
│  └── Controls: group-wide brand policies, AI model baselines    │
│                                                                  │
│  LEVEL 2: FRANCHISEE (e.g., "RetailCorp — India Franchise LLC") │
│  └── Controls: tenant config, staff, pricing rules, reports     │
│      Has: isolated schema, isolated secrets, isolated billing   │
│                                                                  │
│  LEVEL 3: REGION (within a franchisee)                         │
│  └── Controls: regional overrides, regional promotions          │
│                                                                  │
│  LEVEL 4: STORE (physical location)                            │
│  └── Controls: store hours, local staff, store-level reports   │
│                                                                  │
│  LEVEL 5: POS TERMINAL (device)                                │
│  └── Controls: terminal config, receipt header, language        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 10.2 Tenant Provisioning Workflow

```
HQ Approves Franchisee Onboarding
            │
  ┌─────────▼─────────────────────────────────────────────────┐
  │  TENANT PROVISIONING PIPELINE (Azure DevOps + Terraform)  │
  │                                                            │
  │  Step 1: Identity                                          │
  │  ├ Create AAD B2C tenant app registration                 │
  │  ├ Create service principal for franchisee                │
  │  └ Issue admin credentials + MFA enrollment invite        │
  │                                                            │
  │  Step 2: Data Isolation                                    │
  │  ├ Create schema: franchisee_{id} in Azure SQL            │
  │  ├ Create DB user with schema-scoped permissions          │
  │  ├ Store credentials in Key Vault (tenant-scoped vault)   │
  │  └ Enable geo-replication to correct Azure region        │
  │                                                            │
  │  Step 3: Compute                                           │
  │  ├ Create AKS namespace: franchisee-{id}                  │
  │  ├ Apply NetworkPolicy (no cross-namespace traffic)       │
  │  ├ Deploy tenant microservices via GitOps (Flux)          │
  │  └ Configure APIM product with tenant-scoped policies     │
  │                                                            │
  │  Step 4: Event Streaming                                   │
  │  ├ Create Event Hubs namespace: tenant-{id}               │
  │  ├ Create topics: transactions, inventory, loyalty, audit │
  │  └ Configure consumer groups per service                  │
  │                                                            │
  │  Step 5: AI Configuration                                  │
  │  ├ Create Azure ML workspace partition for tenant         │
  │  ├ Seed product catalogue from HQ master                  │
  │  ├ Bootstrap AI models (HQ baseline versions)             │
  │  └ Schedule initial demand forecast run                   │
  │                                                            │
  │  Step 6: Edge Provisioning                                 │
  │  ├ Register store edge device in IoT Hub                  │
  │  ├ Deploy IoT Edge manifest (AI modules)                  │
  │  ├ Push initial model bundle to edge                      │
  │  └ POS enrollment tokens generated                        │
  │                                                            │
  │  TARGET: Full provisioning < 4 hours (automated)          │
  └────────────────────────────────────────────────────────────┘
```

---

## 10.3 Tenant Configuration Model

| Configuration Tier | Who Sets It | Franchisee Can Override? | Example |
|---|---|---|---|
| Platform policy | HQ Platform Team | ❌ Never | Encryption standards, compliance controls |
| Brand policy | HQ Brand Team | ❌ Never | Brand voice, logo, receipt format |
| Regional compliance | HQ Legal | ❌ Never | GDPR consent flows, data residency |
| AI model baseline | HQ AI Team | ✅ Fine-tune only | Promo ranking weights |
| Pricing rules | HQ (master) | ✅ Within bounds | Local pricing offsets |
| Promotions | HQ templates | ✅ Full | Local promotions |
| Product catalogue | HQ (master) | ✅ Add local SKUs | Local-only products |
| Staff management | Franchisee | ✅ Full | Staff roles, schedules |
| Store config | Franchisee | ✅ Full | Store hours, language |
| POS terminal config | Store Manager | ✅ Limited | Receipt header, terminal name |

---

## 10.4 Tenant Data Residency

| Franchisee Region | Azure Primary Region | Azure DR Region | Data Regulation Applied |
|---|---|---|---|
| India | Central India (Pune) | South India | India DPDP Act 2023 |
| EU (Germany) | Germany West Central | France Central | GDPR |
| EU (France) | France Central | Germany West Central | GDPR |
| China | China East 2 | China North 2 | China PIPL / MLPS |
| USA | East US 2 | West US 3 | CCPA (California tenants) |
| UK | UK South | UK West | UK GDPR |
| Australia | Australia East | Australia Southeast | Privacy Act 1988 |

---

---

# PAGE 11 — SECURITY & COMPLIANCE ARCHITECTURE

---

## 11.1 Zero Trust Security Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    ZERO TRUST ARCHITECTURE                             │
│                                                                         │
│  PRINCIPLE: "Never trust, always verify" — every request authenticated  │
│  at every layer regardless of network location                          │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  IDENTITY LAYER                                                 │   │
│  │  Azure Active Directory (staff) + AAD B2C (customers)          │   │
│  │  Device identity: X.509 certificates (TPM-backed on POS)       │   │
│  │  Service identity: Managed Identities (no secrets in code)     │   │
│  │  MFA: enforced for all admin, manager, franchisee roles        │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  NETWORK LAYER                                                  │   │
│  │  Azure Virtual WAN (hub-spoke per region)                      │   │
│  │  Private Endpoints: SQL, Event Hubs, Key Vault, ACR            │   │
│  │  Network Security Groups: deny-all default, allow-list rules   │   │
│  │  Azure Firewall Premium: IDPS, TLS inspection, FQDN rules      │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  APPLICATION LAYER                                              │   │
│  │  APIM: OAuth2 + JWT validation on every API call               │   │
│  │  Tenant context injection: middleware validates tenant claim    │   │
│  │  API scopes: fine-grained per resource, per tenant             │   │
│  │  OWASP Top 10: WAF rules enforced at Azure Front Door          │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  DATA LAYER                                                     │   │
│  │  Encryption at rest: AES-256 (Azure-managed + CMK option)      │   │
│  │  Encryption in transit: TLS 1.3 everywhere                     │   │
│  │  Column-level encryption: PAN, PII fields                      │   │
│  │  Tokenisation: all card data (P2PE at POS, never in plaintext) │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 11.2 PCI-DSS v4.0 Controls

| PCI-DSS Requirement | Architecture Control |
|---|---|
| Req 1: Network security controls | Azure NSG, Firewall Premium, Private Endpoints |
| Req 2: Secure configurations | CIS Benchmark for Windows/Linux, AKS hardened |
| Req 3: Protect stored cardholder data | P2PE at POS; no PAN stored; token-only |
| Req 4: Protect data in transit | TLS 1.3 mandatory; no TLS 1.1/1.0 |
| Req 5: Anti-malware | Microsoft Defender for Endpoint (all devices) |
| Req 6: Secure development | SAST (Checkmarx), DAST, SCA; PCI-aware SDLC |
| Req 7: Restrict access | RBAC + Azure AD PIM; least privilege |
| Req 8: Identity management | MFA all admin; device certificates POS |
| Req 9: Physical security | Site security standards; POS tamper detection |
| Req 10: Audit logging | Azure Monitor + Sentinel; immutable logs |
| Req 11: Security testing | Quarterly ASV scan; annual penetration test |
| Req 12: Information security policy | Documented; ARB-enforced |

**Cardholder Data Environment (CDE) Scope:**
- POS terminal (P2PE reduces scope — validated P2PE solution)
- Payment service in AKS (isolated namespace, network policy)
- Azure SQL payment tables (column-level encrypted)
- Azure Key Vault (payment tokenisation keys)

---

## 11.3 GDPR / CCPA / DPDP / PIPL Controls

### Data Subject Rights Automation

```
Right to Access / Portability:
Request received (portal/API) → Identity verified (AAD B2C)
→ Data Discovery Service queries tenant schema
→ Collects: profile, transactions, loyalty, consent records
→ Generates: machine-readable export (JSON/CSV)
→ Delivered via secure link: ≤ 30 days SLA

Right to Erasure ("Right to be Forgotten"):
Request verified → Erasure Orchestrator triggered
→ PII Scrubber: nullifies PII in tenant SQL schema
→ Event Hubs: replaces PII in historical events with [REDACTED]
→ AI Training Data: removes customer records from feature store
→ Analytics: purges from Synapse
→ Edge: triggers deletion on next store sync
→ Certificate: issued within 24h SLA
→ Audit record: immutable, retained 7 years

Consent Management:
Azure Purview Data Catalog tracks all PII fields
Consent stored: per customer, per purpose, timestamped
Consent withdrawal: triggers erasure pipeline above
```

### Regulation Coverage Matrix

| Control | GDPR | CCPA | India DPDP | China PIPL |
|---|---|---|---|---|
| Lawful basis for processing | ✅ | ✅ | ✅ | ✅ |
| Consent management | ✅ | ✅ | ✅ | ✅ |
| Data subject rights | ✅ | ✅ | ✅ | ✅ |
| Data residency enforcement | ✅ EU only | ✅ CA flag | ✅ India region | ✅ China region |
| Data breach notification | 72h GDPR | 72h CCPA | 72h DPDP | 24h PIPL |
| Cross-border transfer controls | SCCs | — | DPA required | PIPL assessment |
| DPO/CPO appointment | ✅ Required | ✅ Recommended | ✅ Required | ✅ Required |
| AI profiling restrictions | ✅ GDPR Art 22 | ✅ | ✅ | ✅ |

---

## 11.4 Identity & Access Management

### Role Definitions

| Role | Scope | Permissions | MFA Required |
|---|---|---|---|
| Platform Admin | Platform-wide | All | ✅ + PIM |
| HQ Enterprise Admin | All tenants (read) | View, audit, compliance | ✅ + PIM |
| Franchisee Admin | Own tenant only | Full tenant config | ✅ |
| Store Manager | Own store | Store config, reports | ✅ |
| Cashier/POS Staff | POS terminal only | Transactions, returns | PIN + Badge |
| AI Model Engineer | Azure ML workspace | Model training, deploy | ✅ + PIM |
| DevOps Engineer | CI/CD, AKS | Deploy to non-prod | ✅ + PIM for prod |
| Read-only Auditor | All tenant audit logs | Read-only | ✅ |
| Customer (Loyalty) | Own profile only | View, DSAR | Email OTP |

---

## 11.5 Security Monitoring & Incident Response

```
┌───────────────────────────────────────────────────────────────┐
│           SECURITY OPERATIONS CENTER (SOC) ARCHITECTURE      │
│                                                               │
│  Data Sources:                                                │
│  ├ Azure Monitor (all platform services)                     │
│  ├ Microsoft Sentinel (SIEM/SOAR)                            │
│  ├ Defender for Cloud (cloud posture)                        │
│  ├ Defender for Endpoint (POS + edge devices)                │
│  ├ Defender for Containers (AKS)                             │
│  └ Azure Front Door / APIM access logs                       │
│                                                               │
│  Detection Rules (Sentinel Analytics):                        │
│  ├ Cross-tenant data access attempt                          │
│  ├ Unusual transaction velocity (>3σ from baseline)          │
│  ├ Offline payment ceiling breach attempt                    │
│  ├ POS device certificate mismatch                           │
│  ├ AI model tampering (hash mismatch)                        │
│  └ Privileged identity escalation                            │
│                                                               │
│  Incident Response Tiers:                                     │
│  P1 (< 15 min): Payment system breach, data exfiltration     │
│  P2 (< 1 hour): Cross-tenant access, fraud surge             │
│  P3 (< 4 hours): Offline payment anomaly, device anomaly     │
│  P4 (< 24 hours): Policy violation, config drift             │
└───────────────────────────────────────────────────────────────┘
```

---

---

# PAGE 12 — INTEGRATION ARCHITECTURE

---

## 12.1 API Strategy

### API Tiers

| API Tier | Consumers | Gateway | Authentication | Rate Limit |
|---|---|---|---|---|
| POS Terminal API | POS app, Store Edge | Azure APIM (internal) | X.509 + JWT | 1000 req/s per device |
| Store Management API | Store Manager app | Azure APIM | AAD OAuth2 | 100 req/s per store |
| Franchisee Admin API | Franchisee portal | Azure APIM | AAD OAuth2 + RBAC | 50 req/s per tenant |
| HQ Platform API | HQ applications | Azure APIM (private) | AAD + PIM | Unrestricted internal |
| Partner API | Payment providers, ERP | Azure APIM (external) | mTLS + API Key | Per SLA agreement |
| AI Inference API | All services | Azure APIM → AKS | JWT + tenant scope | Model-specific quota |

---

## 12.2 Event-Driven Integration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                  EVENT-DRIVEN ARCHITECTURE                             │
│                                                                         │
│  Event Producers:                                                       │
│  POS Terminal → transaction.completed, transaction.voided              │
│  POS Terminal → payment.processed, payment.failed                      │
│  Store Edge  → inventory.updated, stock.alert                          │
│  AI Platform → fraud.alert, recommendation.generated                   │
│  Loyalty Svc → points.accrued, reward.redeemed                         │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────┐       │
│  │  Azure Event Hubs (per-tenant namespace)                    │       │
│  │  Retention: 7 days │ Partitions: 32 │ Consumer groups: 5   │       │
│  └───────────────────────────┬──────────────────────────────────┘       │
│                              │                                          │
│         ┌────────────────────┼──────────────────────────────┐           │
│         │                    │                              │           │
│  ┌──────▼──────┐   ┌─────────▼──────┐   ┌─────────────────▼────────┐   │
│  │  Stream     │   │   Azure        │   │     Azure Functions      │   │
│  │  Analytics  │   │   ML           │   │     (event handlers)     │   │
│  │  (CRDT      │   │   (training    │   │     - Loyalty update     │   │
│  │   merge,    │   │    data        │   │     - Inventory alert    │   │
│  │   real-time)│   │    ingestion)  │   │     - Notification send  │   │
│  └──────┬──────┘   └─────────┬──────┘   └─────────────────┬────────┘   │
│         │                    │                             │            │
│  ┌──────▼──────┐   ┌─────────▼──────┐   ┌─────────────────▼────────┐   │
│  │  Azure SQL  │   │  Data Lake     │   │  Azure Service Bus       │   │
│  │  (canonical)│   │  Gen2          │   │  (command messages,      │   │
│  │             │   │  (AI training) │   │   RPC-style flows)       │   │
│  └─────────────┘   └────────────────┘   └──────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 12.3 External Integration Map

| System | Integration Type | Protocol | Direction | Notes |
|---|---|---|---|---|
| Payment Gateway (Adyen/Stripe) | Webhook + REST | HTTPS mTLS | Bidirectional | P2PE, PCI-DSS scope |
| ERP (SAP/Oracle) | REST + EDI | HTTPS / AS2 | Bidirectional | Inventory, financials |
| WMS (Warehouse) | REST + Event | HTTPS + Event Hub | Bidirectional | Replenishment orders |
| CRM (Salesforce) | REST + CDC | HTTPS | Bidirectional | Customer 360 |
| E-commerce Platform | REST + Webhook | HTTPS | Bidirectional | Unified inventory |
| Loyalty Partners | REST | HTTPS | Bidirectional | Points exchange |
| Tax Engine (Avalara/Vertex) | REST | HTTPS | Request-Response | Real-time tax calc |
| FX Rate Service | REST | HTTPS | Inbound | 15-min refresh |
| Weather API | REST | HTTPS | Inbound | Demand forecast input |
| ITSM (ServiceNow) | REST | HTTPS | Outbound | Maintenance alerts |

---

---

# PAGE 13 — PHASE E & F: OPPORTUNITIES, SOLUTIONS & MIGRATION PLANNING

---

## 13.1 Gap Analysis Summary

| Capability Area | As-Is | To-Be | Gap | Priority |
|---|---|---|---|---|
| POS Software | Siloed, per-franchisee bespoke | Unified platform, per-tenant config | Platform build | Critical |
| Offline Resilience | Manual paper fallback | Automated edge sync | Architecture + dev | Critical |
| AI Fraud Detection | Rule-based | Real-time ML at POS | ML + MLOps build | High |
| Demand Forecasting | Spreadsheets | Azure ML TFT model | Data + ML pipeline | High |
| Personalisation | Generic loyalty points | AI-driven 1:1 promos | AI + data platform | High |
| Self-Checkout CV | None | YOLOv8 edge models | Camera infra + ML | Medium |
| NLP Assistant | None | Azure OpenAI RAG | App build + KB | Medium |
| Predictive Maintenance | Reactive support | Azure IoT + ML | IoT + telemetry | Medium |
| Multitenancy | Per-franchise silo deploys | Schema-per-tenant platform | Platform refactor | Critical |
| Data Governance | Manual / inconsistent | Azure Purview + policies | Tool + process | High |
| Compliance Automation | Manual audit | Continuous automated controls | Tooling | High |

---

## 13.2 Solution Architecture Roadmap — 3 Horizons

### Horizon 1 — Foundation (Months 1–9): "Platform & Offline"

```
DELIVERABLES:
├── H1.1  Azure platform provisioning (AKS, APIM, Event Hubs, SQL)
├── H1.2  Tenant provisioning automation (Terraform + DevOps pipelines)
├── H1.3  Core POS application (transaction engine, offline mode, sync)
├── H1.4  POS offline architecture (SQLite, outbox, ONNX fraud model)
├── H1.5  Store edge node (K3s, PostgreSQL, IoT Edge)
├── H1.6  Schema-per-tenant data isolation
├── H1.7  Identity & Access Management (AAD, B2C, RBAC)
├── H1.8  PCI-DSS controls (P2PE, tokenisation, network isolation)
└── H1.9  Pilot: 2 franchisees, 20 stores

SUCCESS CRITERIA:
- POS processes transactions offline for 72h with zero data loss
- Tenant provisioning < 4 hours
- PCI-DSS SAQ-P2PE compliant
- 99.9% transaction success rate (online + offline)
```

### Horizon 2 — Intelligence (Months 10–18): "AI at Scale"

```
DELIVERABLES:
├── H2.1  Azure ML platform + MLOps pipelines
├── H2.2  Demand forecasting (TFT model, per tenant)
├── H2.3  Real-time fraud detection (ONNX edge + cloud ensemble)
├── H2.4  Personalised promotions (collaborative filtering + bandits)
├── H2.5  NLP store assistant (Azure OpenAI + RAG)
├── H2.6  Predictive maintenance (IoT telemetry + Azure Digital Twins)
├── H2.7  GDPR/CCPA automated rights management
├── H2.8  Azure Purview data governance
└── H2.9  Scale: 50 franchisees, 500 stores

SUCCESS CRITERIA:
- Fraud detection rate > 94%; false positive rate < 2%
- Demand forecast MAPE < 12%
- Personalisation lift: basket value +8% vs. control
- NLP assistant deflects 35% of staff queries
```

### Horizon 3 — Optimisation (Months 19–30): "Global Scale & Innovation"

```
DELIVERABLES:
├── H3.1  Computer vision self-checkout (YOLOv8 per franchisee)
├── H3.2  Shelf analytics (planogram, out-of-stock detection)
├── H3.3  China PIPL + India DPDP region deployments
├── H3.4  Full global rollout (5000+ stores)
├── H3.5  AI model marketplace (franchisees access HQ models)
├── H3.6  Autonomous replenishment (AI PO without manual approval)
├── H3.7  Carbon/sustainability analytics
└── H3.8  Real-time cross-franchisee benchmarking (anonymised)

SUCCESS CRITERIA:
- Global coverage: 5000+ stores, 50+ countries
- Self-checkout accuracy > 98.5%
- Replenishment efficiency: stockout rate -30%
- Platform TCO: < USD 0.001 per transaction
```

---

## 13.3 Risk Register

| Risk ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R01 | POS offline data loss during sync | Low | Critical | Event sourcing + CRDT; immutable outbox |
| R02 | Cross-tenant data leakage | Very Low | Critical | Schema isolation + RLS + APIM policy |
| R03 | AI fraud model bias (false positives) | Medium | High | Fairlearn bias checks; A/B testing; human override |
| R04 | Azure region outage | Very Low | High | Multi-region active-active; store edge autonomy |
| R05 | GDPR breach notification miss | Low | Critical | Automated Sentinel alert < 24h; DPO workflow |
| R06 | Payment processing offline ceiling exceeded | Low | Medium | HQ-signed config; real-time monitoring; alerts |
| R07 | AI model drift degrading fraud detection | Medium | High | Evidently AI monitoring; auto-retrain trigger |
| R08 | Franchisee non-compliance with platform policies | Medium | High | Policy-as-code; ARB enforcement; audit reports |
| R09 | IoT Edge model OTA failure | Low | Medium | Canary deployment; automatic rollback |
| R10 | Store edge hardware failure (no HA) | Medium | Medium | POS offline fallback; SLA for replacement < 4h |

---

---

# PAGE 14 — PHASES G & H: GOVERNANCE & CHANGE MANAGEMENT

---

## 14.1 Architecture Governance Framework

```
┌─────────────────────────────────────────────────────────────────────────┐
│              ARCHITECTURE REVIEW BOARD (ARB)                           │
│                                                                         │
│  COMPOSITION:                                                           │
│  ├ Group CTO (Chair)                                                   │
│  ├ Enterprise Architect (Secretary)                                    │
│  ├ CISO                                                                │
│  ├ CDO                                                                 │
│  ├ Head of Retail Technology                                           │
│  └ Franchisee Representative (rotating)                                │
│                                                                         │
│  CADENCE: Monthly for tactical; Quarterly for strategic review         │
│                                                                         │
│  ARB GATE CRITERIA (all new components must satisfy):                  │
│  ├ Aligns to Architecture Principles (Page 1.2)                       │
│  ├ No cross-tenant data leakage risk                                   │
│  ├ Offline resilience not degraded                                     │
│  ├ PCI-DSS CDE scope impact assessed                                   │
│  ├ AI model governance requirements met                                │
│  └ ADR (Architecture Decision Record) filed                            │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 14.2 KPIs & SLAs

### Platform SLAs

| Metric | Target | Measurement |
|---|---|---|
| POS transaction success rate | 99.99% (online), 99.9% (offline) | Azure Monitor |
| Store-to-cloud sync latency (p99) | < 60 seconds on reconnect | Stream Analytics |
| Tenant provisioning time | < 4 hours | DevOps pipeline metrics |
| API availability (APIM) | 99.95% | Azure Front Door health |
| AI inference latency (fraud, p99) | < 200ms (edge) | APIM + AKS metrics |
| Data breach notification | < 72 hours (GDPR) | Sentinel automation |
| Offline operation duration | Indefinite (tested to 72h+) | Store edge monitoring |

### AI Model KPIs

| Model | KPI | Target | Monitoring |
|---|---|---|---|
| Fraud detection | True positive rate | > 94% | Evidently AI |
| Fraud detection | False positive rate | < 2% | Evidently AI |
| Demand forecast | MAPE | < 12% | Azure ML monitor |
| Personalisation | Basket value lift vs. control | > 8% | A/B test framework |
| CV self-checkout | Item recognition accuracy | > 98.5% | Azure Custom Vision |
| NLP assistant | Intent classification accuracy | > 92% | Azure AI metrics |
| Predictive maintenance | Failure prediction lead time | > 48 hours | IoT Hub + ADX |

---

## 14.3 Architecture Change Management Process

```
CHANGE REQUEST INITIATED
(by: Franchisee, Dev Team, HQ Business)
        │
        ▼
IMPACT ASSESSMENT
├ Architecture impact (EA team, 5 days)
├ PCI/compliance impact (CISO, 3 days)
├ Tenant isolation impact (Platform team)
└ AI model impact (CDO team)
        │
        ▼
CLASSIFICATION
├ Standard: Pre-approved patterns → Fast track (48h)
├ Significant: ARB monthly review → Full ADR required
└ Major: Special ARB session → Architecture sprint
        │
        ▼
ARB DECISION
├ Approve → Development proceeds
├ Approve with conditions → Dev with architectural guard
└ Reject → Alternatives explored
        │
        ▼
IMPLEMENTATION
GitOps pipeline → AKS deployment → IoT Edge update
        │
        ▼
ARCHITECTURE BASELINE UPDATED
ADR filed → EA repository → Confluence documentation
        │
        ▼
POST-IMPLEMENTATION REVIEW (30 days)
Metrics vs. targets → Lessons learned → Principle update if needed
```

---

## 14.4 AI Governance Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────┐
│                   AI MODEL GOVERNANCE LIFECYCLE                        │
│                                                                         │
│  CONCEPTION                                                             │
│  ├ Business case + AI ethics review                                    │
│  ├ Data lineage audit (Purview)                                        │
│  └ Bias risk assessment (protected characteristics)                    │
│                                                                         │
│  DEVELOPMENT                                                            │
│  ├ Feature engineering (Azure ML Feature Store)                       │
│  ├ Model training (Azure ML pipelines, reproducible)                   │
│  ├ Bias detection (Fairlearn — gender, ethnicity, age)                 │
│  └ Explainability (SHAP values computed, stored)                       │
│                                                                         │
│  VALIDATION                                                             │
│  ├ Held-out test set evaluation                                        │
│  ├ A/B test (5% traffic → canary)                                      │
│  ├ ARB AI approval (CDO sign-off)                                      │
│  └ Model card published (public for GDPR Art 13/14)                   │
│                                                                         │
│  DEPLOYMENT                                                             │
│  ├ Model Registry version tagged (SHA256 hash)                        │
│  ├ Deployed to: Cloud (AKS) → Store Edge (IoT) → POS (ONNX bundle)    │
│  └ Canary → staged → full rollout                                      │
│                                                                         │
│  MONITORING                                                             │
│  ├ Evidently AI: data drift, concept drift (daily)                    │
│  ├ Azure ML model monitor: performance vs. baseline                    │
│  ├ Bias re-check (monthly)                                             │
│  └ Auto-trigger: retrain if drift score > threshold                    │
│                                                                         │
│  RETIREMENT                                                             │
│  ├ Successor model validated and deployed                              │
│  ├ Old model archived (not deleted — compliance)                       │
│  └ Training data retained per regulation (7 years financial)           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 14.5 Non-Functional Requirements Summary

| NFR | Category | Target |
|---|---|---|
| Availability | Platform (cloud) | 99.95% per month |
| Availability | Store Edge | 99.9% per month |
| Availability | POS (offline-inclusive) | 99.99% transaction success |
| Performance | POS transaction close time | < 3 seconds (online), < 1 second (offline) |
| Performance | Fraud scoring latency | < 200ms (p99, edge) |
| Performance | API response time | < 500ms (p95, APIM) |
| Scalability | Peak transactions per second | 100,000 TPS (global aggregate) |
| Scalability | Tenants supported | 10,000+ franchisees |
| Durability | Transaction data | Zero loss guaranteed (event sourcing) |
| Recovery | Cloud RTO | < 4 hours (regional failover) |
| Recovery | Store Edge RTO | < 30 seconds (HA failover) |
| Recovery | POS RTO | Instant (local-first, no recovery needed) |
| Data Retention | Transaction records | 7 years (financial regulation) |
| Data Retention | PII (customer) | Per GDPR/DPDP consent duration |
| Security | Encryption at rest | AES-256 |
| Security | Encryption in transit | TLS 1.3 |
| Compliance | PCI-DSS scope | P2PE reduced scope |
| Compliance | GDPR erasure SLA | 24 hours |

---

---

# APPENDIX A — ARCHITECTURE DECISION RECORDS (INDEX)

| ADR ID | Title | Status | Approved |
|---|---|---|---|
| ADR-001 | Azure as primary cloud platform | Approved | 2026-01 |
| ADR-002 | Schema-per-tenant isolation model | Approved | 2026-01 |
| ADR-003 | Event sourcing with Azure Event Hubs | Approved | 2026-01 |
| ADR-004 | K3s for store edge orchestration | Approved | 2026-02 |
| ADR-005 | Azure IoT Edge for AI model deployment | Approved | 2026-02 |
| ADR-006 | ONNX Runtime for POS AI inference | Approved | 2026-02 |
| ADR-007 | CRDT-based offline conflict resolution | Approved | 2026-03 |
| ADR-008 | P2PE payment tokenisation at POS | Approved | 2026-01 |
| ADR-009 | Azure OpenAI GPT-4o for NLP assistant | Approved | 2026-03 |
| ADR-010 | Temporal Fusion Transformer for demand forecasting | Proposed | 2026-04 |
| ADR-011 | Flux v2 GitOps for deployment | Approved | 2026-02 |
| ADR-012 | Phi-3 Mini SLM for offline NLP fallback | Proposed | 2026-04 |

---

# APPENDIX B — TECHNOLOGY STACK SUMMARY

| Layer | Component | Technology | Version |
|---|---|---|---|
| Cloud Platform | Container Orchestration | Azure Kubernetes Service (AKS) | 1.29+ |
| Cloud Platform | API Management | Azure API Management | v2 |
| Cloud Platform | Event Streaming | Azure Event Hubs (Kafka compat.) | Standard+ |
| Cloud Platform | Messaging | Azure Service Bus | Premium |
| Cloud Platform | Database | Azure SQL / PostgreSQL Flexible | PG 16 |
| Cloud Platform | AI/ML | Azure Machine Learning | v2 SDK |
| Cloud Platform | GenAI | Azure OpenAI | GPT-4o, Ada-002 |
| Cloud Platform | Vector Search | Azure AI Search | 2024 |
| Cloud Platform | IoT | Azure IoT Hub + IoT Edge | 1.4 |
| Cloud Platform | Secrets | Azure Key Vault | Premium (HSM) |
| Cloud Platform | CDN/WAF | Azure Front Door | Premium |
| Cloud Platform | SIEM | Microsoft Sentinel | — |
| Edge | Orchestration | K3s | 1.29+ |
| Edge | AI Runtime | Azure IoT Edge + ONNX Runtime | — |
| Edge | Database | PostgreSQL | 16 |
| Edge | Message Queue | Apache Kafka (Confluent) | 3.6 |
| POS | OS | Windows 10 IoT / Android 13+ | — |
| POS | App Framework | .NET 8 / Java 21 | — |
| POS | Local DB | SQLite | 3.44 |
| POS | AI Inference | ONNX Runtime | 1.17 |
| POS | Payments | Verifone P400 SDK / Android PAX | — |
| DevOps | CI/CD | Azure DevOps Pipelines | — |
| DevOps | GitOps | Flux v2 | — |
| DevOps | IaC | Terraform + Azure Bicep | TF 1.7 |
| DevOps | Container Registry | Azure Container Registry | Premium |
| DevOps | SAST | Checkmarx | — |
| MLOps | Experiment Tracking | Azure ML + MLflow | — |
| MLOps | Drift Monitoring | Evidently AI | — |
| MLOps | Explainability | SHAP + LIME | — |
| MLOps | Bias Detection | Fairlearn | — |
| Observability | Metrics/Logs | Azure Monitor + Application Insights | — |
| Observability | Dashboards | Azure Managed Grafana | — |
| Observability | IoT Analytics | Azure Data Explorer (ADX) | — |

---

# APPENDIX C — GLOSSARY

| Term | Definition |
|---|---|
| ADM | Architecture Development Method (TOGAF) |
| ARB | Architecture Review Board |
| CRDT | Conflict-free Replicated Data Type — mathematical data structure enabling deterministic merge of concurrent updates |
| CDE | Cardholder Data Environment (PCI-DSS scoped area) |
| CDC | Change Data Capture — streaming DB changes as events |
| CMK | Customer-Managed Keys (Azure encryption option) |
| DPDP | Digital Personal Data Protection Act (India 2023) |
| Edge | Compute deployed at store level, close to POS devices |
| Event Outbox | Reliable pattern ensuring events are published to message bus only after local DB commit |
| GitOps | Infrastructure and deployment managed declaratively via Git |
| MAPE | Mean Absolute Percentage Error (forecast accuracy metric) |
| MLOps | Machine Learning Operations — DevOps practices for ML lifecycle |
| ONNX | Open Neural Network Exchange — cross-platform ML model format |
| P2PE | Point-to-Point Encryption — encrypts card data at swipe/tap, reducing PCI scope |
| PIPL | Personal Information Protection Law (China 2021) |
| RAG | Retrieval Augmented Generation — LLM enhanced with real-time knowledge retrieval |
| Schema-per-tenant | Database isolation model where each tenant has a dedicated schema (namespace) within a shared DB instance |
| SLM | Small Language Model (e.g., Phi-3 Mini) — compact LLM suitable for edge deployment |
| TFT | Temporal Fusion Transformer — state-of-the-art time series forecasting model |
| Zero Trust | Security model where no entity is trusted by default, regardless of network location |

---

*End of Document*

---

**Document Control**  
This document is classified as Restricted — Enterprise Architecture.  
Distribution limited to: Architecture Review Board, CTO Office, CISO, CDO.  
External distribution requires written approval from Group CTO.

**Next Review:** December 2026  
**Document Owner:** Enterprise Architecture Office  
**Version:** 1.0.0 — Approved Baseline

