# HLD-001 — System Architecture Overview
## EnterpriseRetailAI · Global Retail POS Platform

---

| Attribute | Value |
|---|---|
| Document ID | HLD-001 |
| Type | High-Level Design |
| Version | 1.0 |
| Status | Approved |
| Author | Enterprise Architecture |
| Date | June 2026 |

---

## 1. Purpose

This document provides the end-to-end system architecture overview of the EnterpriseRetailAI platform. It describes the three-tier deployment topology (POS Edge → Store Edge → Cloud), the principal components at each tier, and how they interact to deliver offline-first, AI-enhanced retail operations across a mixed HQ and global franchisee estate.

---

## 2. System Context

```
╔══════════════════════════════════════════════════════════════════════════╗
║                        SYSTEM CONTEXT DIAGRAM                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  EXTERNAL ACTORS:                                                        ║
║  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  ║
║  │  Customer   │  │ Franchisee   │  │  HQ Admin    │  │  Payment    │  ║
║  │ (shopper)   │  │  Admin       │  │  & CTO       │  │  Gateway    │  ║
║  └──────┬──────┘  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘  ║
║         │                │                  │                 │          ║
║         │          ┌─────▼──────────────────▼─────────────────▼──────┐  ║
║         │          │                                                  │  ║
║         │          │         EnterpriseRetailAI Platform              │  ║
║         │          │                                                  │  ║
║         │          │  ┌──────────────────────────────────────────┐    │  ║
║  POS    │          │  │  POS Terminal Layer (Device Edge)        │    │  ║
║  Touch  ├──────────┼─►│  Windows .NET / Android Java             │    │  ║
║         │          │  └──────────────────────────────────────────┘    │  ║
║         │          │                 │                                 │  ║
║         │          │  ┌──────────────▼───────────────────────────┐    │  ║
║         │          │  │  Store Edge Layer (On-Premises)          │    │  ║
║         │          │  │  K3s + IoT Edge + PostgreSQL             │    │  ║
║         │          │  └──────────────────────────────────────────┘    │  ║
║         │          │                 │                                 │  ║
║         │          │  ┌──────────────▼───────────────────────────┐    │  ║
║         │          │  │  Cloud Layer (Azure Multi-Region)        │    │  ║
║         │          │  │  AKS + Event Hubs + Azure ML + APIM      │    │  ║
║         │          │  └──────────────────────────────────────────┘    │  ║
║         │          └──────────────────────────────────────────────────┘  ║
║         │                                                                 ║
║  ┌──────▼─────────────────────────────────────────────────────────────┐  ║
║  │  External Systems: ERP (SAP) │ WMS │ CRM (Salesforce) │ FX Rates  │  ║
║  └────────────────────────────────────────────────────────────────────┘  ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## 3. Three-Tier Deployment Topology

### 3.1 Tier 1 — POS Terminal (Device Edge)

**Location:** Physical POS terminal on the shop floor  
**Hardware:** Windows 10 IoT Enterprise workstation OR Android 13+ tablet/appliance  
**Connectivity:** LAN to Store Edge (required), WAN optional  
**Offline Capability:** 100% — indefinite autonomous operation

**Responsibilities:**
- Accept and process customer transactions
- Scan barcodes, apply pricing, promotions, tax
- Interface with payment terminal (Verifone/PAX) via P2PE SDK
- Run local AI inference (fraud scoring, promo ranking) via ONNX Runtime
- Persist all transactions to local SQLite in append-only event log
- Queue events for store edge synchronisation
- Print receipts, manage cashier shift

**Technology Stack:**

| Component | Windows POS | Android POS |
|---|---|---|
| Application | .NET 8 WPF/WinUI | Java 21 / Kotlin Android |
| Local DB | SQLite 3.44 | SQLite 3.44 |
| AI Runtime | ONNX Runtime 1.17 | ONNX Runtime Android |
| Payment SDK | Verifone Commander SDK | PAX Android SDK |
| Sync | Rust-based sync agent | Rust (JNI) / Kotlin coroutine |
| Packaging | MSIX / WinGet | APK (enterprise signed) |
| Update | Azure IoT Hub + MSIX | Android Enterprise / IoT Hub |

---

### 3.2 Tier 2 — Store Edge Server (On-Premises)

**Location:** Back-of-house server room or ruggedized rack in each store  
**Hardware:** Intel NUC / Dell Edge 3000 / Industrial PC — Linux Ubuntu 24.04  
**Connectivity:** LAN to POS terminals; WAN to Azure (MPLS primary, 4G/5G failover)  
**Offline Capability:** Full store operation, unlimited duration

**Responsibilities:**
- Aggregate transactions from all POS terminals in the store
- Run store-level AI workloads (CV inference, local NLP, anomaly detection)
- Maintain store-level canonical data (PostgreSQL)
- Manage event queue to cloud (Kafka-compatible, local buffering)
- Deploy and execute Azure IoT Edge AI modules (OTA-updated)
- Serve as local API hub when cloud unreachable
- Coordinate inventory, loyalty, promotions across all POS in store

**Technology Stack:**

| Component | Technology |
|---|---|
| Orchestration | K3s v1.29 (lightweight Kubernetes) |
| AI Runtime | Azure IoT Edge 1.4 + ONNX Runtime |
| Database | PostgreSQL 16 (Patroni HA on Tier A stores) |
| Event Queue | Apache Kafka (Confluent Community) 3.6 |
| Networking | Flannel CNI + MetalLB (bare-metal LB) |
| GitOps | Flux v2 (syncs from Azure DevOps) |
| Monitoring | Prometheus + Grafana (local dashboards) |
| OS | Ubuntu 24.04 LTS (hardened CIS L2) |

---

### 3.3 Tier 3 — Cloud Platform (Azure Multi-Region)

**Location:** Azure data centres — primary regions per franchisee geography  
**Scale:** Active-active multi-region; global Azure backbone  
**Availability Target:** 99.95% platform SLA

**Responsibilities:**
- Host all tenant microservices in isolated AKS namespaces
- Manage the canonical tenant data stores (Azure SQL / PostgreSQL Flexible)
- Run cloud-based AI training and inference (Azure ML, Azure OpenAI)
- Handle global API routing (APIM + Azure Front Door)
- Orchestrate event streaming and processing (Event Hubs)
- Enforce security, compliance, and governance controls
- Provide HQ and franchisee admin portals and reporting

---

## 4. Component Architecture Map

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    COMPLETE COMPONENT MAP                                   │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CLOUD TIER                                                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  Azure Front Door (Global WAF + CDN + Load Balancer)                │    │
│  └────────────────────────────┬─────────────────────────────────────────┘    │
│                               │                                              │
│  ┌────────────────────────────▼─────────────────────────────────────────┐    │
│  │  Azure API Management (Multi-region, per-tenant product policies)   │    │
│  └──────────────────┬─────────────────────────────┬──────────────────────┘    │
│                     │                             │                          │
│  ┌──────────────────▼──────────┐   ┌─────────────▼────────────────────┐      │
│  │  AKS Cluster (per region)  │   │  Azure AI Platform               │      │
│  │                             │   │                                  │      │
│  │  NS: franchisee-{id}       │   │  Azure OpenAI (GPT-4o)           │      │
│  │  ├ POS API Service         │   │  Azure Machine Learning           │      │
│  │  ├ Transaction Service     │   │  Azure AI Search                 │      │
│  │  ├ Inventory Service       │   │  Azure Custom Vision             │      │
│  │  ├ Loyalty Service         │   │  Azure AI Content Safety         │      │
│  │  ├ Payment Service         │   │  Azure Digital Twins             │      │
│  │  ├ Promotion Service       │   │                                  │      │
│  │  ├ Notification Service    │   └──────────────────────────────────┘      │
│  │  ├ Report Service          │                                              │
│  │  └ AI Proxy Service        │   ┌──────────────────────────────────┐      │
│  │                             │   │  Data Platform                  │      │
│  │  NS: platform-shared       │   │  Azure Data Lake Gen2            │      │
│  │  ├ Tenant Mgmt Service     │   │  Azure Synapse Analytics         │      │
│  │  ├ Auth Service            │   │  Azure Purview                   │      │
│  │  ├ Compliance Service      │   │  Power BI Embedded               │      │
│  │  ├ MLOps Orchestrator      │   └──────────────────────────────────┘      │
│  │  └ Admin Portal            │                                              │
│  └─────────────────────────────┘   ┌──────────────────────────────────┐      │
│                                    │  Integration & Messaging         │      │
│  ┌──────────────────────────────┐  │  Azure Event Hubs (per tenant)  │      │
│  │  Data Stores                │  │  Azure Service Bus               │      │
│  │  Azure SQL Flexible         │  │  Azure IoT Hub                   │      │
│  │  (schema per franchisee)    │  │  Azure Event Grid                │      │
│  │  Azure CosmosDB (catalogue) │  └──────────────────────────────────┘      │
│  │  Azure Redis Cache          │                                              │
│  │  Azure Key Vault (per tenant│  ┌──────────────────────────────────┐      │
│  └──────────────────────────────┘  │  Security & Observability       │      │
│                                    │  Microsoft Sentinel              │      │
│                                    │  Microsoft Defender Suite        │      │
│                                    │  Azure Monitor + App Insights    │      │
│                                    │  Azure Managed Grafana           │      │
│                                    └──────────────────────────────────┘      │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  STORE EDGE TIER                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐    │
│  │  K3s Node(s)                        Azure IoT Edge Runtime          │    │
│  │  ┌─────────────────────────────┐    ┌─────────────────────────────┐ │    │
│  │  │ Store Orchestration API     │    │ IoT Edge AI Modules:        │ │    │
│  │  │ Inventory Service           │    │ ├ fraud-detector-edge       │ │    │
│  │  │ Loyalty Service             │    │ ├ demand-forecast-edge      │ │    │
│  │  │ Sync Manager                │    │ ├ cv-item-recognition       │ │    │
│  │  │ NLP SLM Service (Phi-3)     │    │ ├ nlp-phi3-assistant        │ │    │
│  │  │ PostgreSQL (local)          │    │ └ predictive-maint-monitor  │ │    │
│  │  │ Kafka (event queue)         │    └─────────────────────────────┘ │    │
│  │  └─────────────────────────────┘                                     │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  POS TERMINAL TIER                                                           │
│  ┌────────────────────┐  ┌────────────────────┐  ┌──────────────────────┐   │
│  │ Windows POS (.NET) │  │ Android POS (Java) │  │ Self-Checkout Kiosk │   │
│  │ ├ TX Engine        │  │ ├ TX Engine        │  │ ├ CV Camera Feed    │   │
│  │ ├ ONNX Fraud Model │  │ ├ ONNX Fraud Model │  │ ├ Weight Scale API  │   │
│  │ ├ Payment SDK      │  │ ├ Payment SDK      │  │ ├ Anti-theft detect │   │
│  │ ├ Sync Agent       │  │ ├ Sync Agent       │  │ └ Payment terminal  │   │
│  │ └ SQLite DB        │  │ └ SQLite DB        │  └──────────────────────┘   │
│  └────────────────────┘  └────────────────────┘                             │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Key Interaction Flows

### 5.1 Online Transaction Flow
```
Cashier scans items on POS
    │
POS TX Engine: price lookup (local cache) + promo evaluation (ONNX)
    │
Payment: P2PE encrypt → Store Edge → Azure Payment Service → Gateway
    │
Transaction event written to SQLite outbox → Store Edge Kafka → Azure Event Hubs
    │
Inventory updated (eventually consistent) → Loyalty points accrued
    │
Receipt printed locally
```

### 5.2 Store Offline Flow
```
WAN outage detected (IoT Hub ping timeout 30s)
    │
All transactions continue via Store Edge (K3s services)
Store Edge AI modules (IoT Edge): fraud, promo, CV — all local
Payment: offline token engine → tokens stored locally
Events queued in Kafka (local)
    │
WAN restored → Kafka consumer publishes backlog to Azure Event Hubs
Azure Stream Analytics: CRDT merge, dedup, ordered replay
Cloud tenant schema updated → reconciliation report generated
```

### 5.3 AI Model Deployment Flow
```
Azure ML training pipeline completes → model validated → registered
    │
MLOps CD pipeline: AKS inference endpoint updated (cloud)
IoT Hub deployment manifest updated → Edge modules receive OTA update
POS ONNX bundle built → pushed via IoT Hub file upload → POS updates on next restart
    │
Canary: 5% traffic → monitor metrics → auto-promote or rollback
```

---

## 6. Non-Functional Architecture Targets

| Quality Attribute | Target | Achieved By |
|---|---|---|
| Availability | 99.99% transaction success | Offline-first + multi-tier redundancy |
| Performance | < 3s POS close (online), < 1s (offline) | Local SQLite + cached rules |
| Scalability | 100k TPS global aggregate | AKS HPA + Event Hubs partitioning |
| Resilience | 72h+ autonomous store operation | Store edge + POS local stack |
| Security | Zero Trust at every boundary | APIM + mTLS + P2PE + RBAC |
| Observability | Full distributed tracing | App Insights + Grafana + Sentinel |
| AI Latency | < 200ms fraud scoring (p99) | ONNX on POS + edge model |
| Compliance | PCI + GDPR + CCPA + DPDP + PIPL | Controls embedded per tier |

---

## 7. Deployment Regions

| Region | Azure Regions | Franchisees Served | Data Regulations |
|---|---|---|---|
| India | Central India (primary), South India (DR) | India franchisees | DPDP Act 2023 |
| EU West | Germany West Central + France Central | EU franchisees | GDPR |
| Americas | East US 2 + West US 3 | US + LatAm | CCPA, local |
| China | China East 2 + China North 2 | China franchisees | PIPL / MLPS |
| APAC | Southeast Asia + Australia East | APAC (non-China) | Local privacy laws |
| UK | UK South + UK West | UK franchisees | UK GDPR |

---

## 8. Related Documents

| Document | Reference |
|---|---|
| TOGAF EA Document | `00_TOGAF/TOGAF_GlobalRetailPOS_EA_Document.md` |
| POS Application HLD | `01_HLD/HLD-002_POS_Application.md` |
| Store Edge HLD | `01_HLD/HLD-003_Store_Edge_Platform.md` |
| Cloud Platform HLD | `01_HLD/HLD-004_Cloud_Platform_Azure.md` |
| AI/ML Platform HLD | `01_HLD/HLD-005_AI_ML_Platform.md` |
