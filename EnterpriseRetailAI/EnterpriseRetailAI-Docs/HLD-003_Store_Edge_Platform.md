# HLD-003 — Store Edge Platform
## EnterpriseRetailAI · Store Edge Server Architecture

---

| Attribute | Value |
|---|---|
| Document ID | HLD-003 |
| Type | High-Level Design |
| Version | 1.0 |
| Status | Approved |
| Date | June 2026 |

---

## 1. Purpose

This document defines the high-level design of the Store Edge Platform — the on-premises server infrastructure deployed in every retail store. The store edge is the central coordination layer between POS terminals and the Azure cloud, hosting containerised services, local AI inference modules, and the event queue that guarantees zero data loss during cloud disconnection.

---

## 2. Store Edge Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          STORE EDGE SERVER                                │
│                     (Ubuntu 24.04 LTS · K3s Cluster)                     │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐     │
│  │                   K3s KUBERNETES LAYER                          │     │
│  │                                                                  │     │
│  │  ┌──────────────────┐  ┌─────────────────┐  ┌───────────────┐  │     │
│  │  │ Store Orch. API  │  │ Inventory Svc   │  │ Loyalty Svc   │  │     │
│  │  │ (REST + gRPC)    │  │ (real-time)     │  │ (balance mgmt)│  │     │
│  │  │ Port: 8080/8443  │  │ Port: 8082      │  │ Port: 8083    │  │     │
│  │  └──────────────────┘  └─────────────────┘  └───────────────┘  │     │
│  │                                                                  │     │
│  │  ┌──────────────────┐  ┌─────────────────┐  ┌───────────────┐  │     │
│  │  │ Promotion Svc    │  │ Sync Manager    │  │ NLP SLM Svc   │  │     │
│  │  │ (rules + cache)  │  │ (outbox relay)  │  │ (Phi-3 Mini)  │  │     │
│  │  │ Port: 8084       │  │ Port: 8085      │  │ Port: 8086    │  │     │
│  │  └──────────────────┘  └─────────────────┘  └───────────────┘  │     │
│  │                                                                  │     │
│  │  ┌──────────────────┐  ┌─────────────────┐                     │     │
│  │  │ Shift Mgmt Svc   │  │ Report Service  │                     │     │
│  │  │ (EOD, reconcil.) │  │ (local BI)      │                     │     │
│  │  │ Port: 8087       │  │ Port: 8088      │                     │     │
│  │  └──────────────────┘  └─────────────────┘                     │     │
│  └──────────────────────────────────────────────────────────────────┘     │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐     │
│  │                   AZURE IoT EDGE RUNTIME                        │     │
│  │                                                                  │     │
│  │  ┌──────────────────┐  ┌─────────────────┐  ┌───────────────┐  │     │
│  │  │fraud-detect-edge │  │ cv-item-recog   │  │ nlp-phi3-mod  │  │     │
│  │  │ (ONNX LightGBM)  │  │ (YOLOv8 ONNX)  │  │ (Phi-3 Mini)  │  │     │
│  │  └──────────────────┘  └─────────────────┘  └───────────────┘  │     │
│  │                                                                  │     │
│  │  ┌──────────────────┐  ┌─────────────────┐                     │     │
│  │  │demand-fcst-edge  │  │ pred-maint-mon  │                     │     │
│  │  │ (TFT lite ONNX)  │  │ (Isolation Frst)│                     │     │
│  │  └──────────────────┘  └─────────────────┘                     │     │
│  └──────────────────────────────────────────────────────────────────┘     │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐     │
│  │                   DATA & MESSAGING LAYER                        │     │
│  │                                                                  │     │
│  │  ┌────────────────────────┐   ┌───────────────────────────────┐ │     │
│  │  │  PostgreSQL 16          │   │  Apache Kafka 3.6 (local)    │ │     │
│  │  │  (store canonical DB)  │   │  Topics:                     │ │     │
│  │  │  Patroni HA (Tier A)   │   │  ├ tx.completed              │ │     │
│  │  │  Single (Tier B)       │   │  ├ inventory.updated         │ │     │
│  │  └────────────────────────┘   │  ├ loyalty.delta             │ │     │
│  │                               │  ├ payment.tokens            │ │     │
│  │  ┌────────────────────────┐   │  └ device.telemetry          │ │     │
│  │  │  Redis (local cache)   │   └───────────────────────────────┘ │     │
│  │  │  TTL: 15min default    │                                     │     │
│  │  └────────────────────────┘                                     │     │
│  └──────────────────────────────────────────────────────────────────┘     │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────┐     │
│  │                   NETWORKING LAYER                              │     │
│  │  Flannel CNI │ MetalLB (bare-metal LoadBalancer) │ Ingress NGINX│     │
│  │  LAN: 192.168.x.x/24 (POS terminals)                           │     │
│  │  WAN: MPLS/broadband (primary) + 4G/5G USB/PCIe (failover)     │     │
│  └──────────────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Store Edge Services

### 3.1 Store Orchestration API

**Purpose:** Single internal API hub for all POS terminals in the store.  
**Technology:** .NET 8 minimal API + gRPC  
**Protocol:** REST (HTTPS :8080) for POS; gRPC (:8443) for high-frequency telemetry

Endpoints (summary — see LLD-003 for full spec):
- `POST /api/v1/transactions` — accept POS transaction event
- `GET  /api/v1/products/{barcode}` — product lookup
- `GET  /api/v1/promotions` — active promotions for store
- `POST /api/v1/loyalty/accrue` — accrue loyalty points
- `POST /api/v1/payments/token` — create offline payment token
- `GET  /api/v1/store/status` — store mode (ONLINE/OFFLINE)

### 3.2 Sync Manager

**Purpose:** Reliable event forwarding from store edge to Azure Event Hubs.  
**Technology:** Rust (Tokio async runtime) — chosen for reliability and low memory footprint  

**Responsibilities:**
- Consume events from local Kafka topics
- Deduplicate by `idempotency_key` (UUID v7 generated at POS)
- Compress event batches (zstd compression, ~10:1 ratio for transaction events)
- Encrypt batch (AES-256-GCM, tenant key from Key Vault pre-fetched)
- Publish to Azure Event Hubs (AMQP 1.0 with device certificate auth)
- Track ACK per event; retry with exponential backoff on failure
- Never delete from Kafka until ACK confirmed from Event Hubs

**Sync Performance Targets:**

| Condition | Target |
|---|---|
| Online sync latency (p95) | < 5 seconds per event |
| Backlog replay rate | 10,000 events/minute (throttled to protect cloud) |
| Deduplication window | 7 days (Kafka retention) |
| Max queue depth (disk) | 2 million events (~2GB at average event size) |

### 3.3 AI Edge Modules (IoT Edge)

All AI modules are Azure IoT Edge module containers, deployed via IoT Hub device twin manifests. They communicate with K3s services via the IoT Edge module network.

| Module | Framework | Model Format | GPU Required | Memory |
|---|---|---|---|---|
| fraud-detect-edge | ONNX Runtime 1.17 | LightGBM ONNX | No (CPU) | 256 MB |
| cv-item-recognition | ONNX Runtime + OpenCV | YOLOv8n ONNX | Optional (CUDA) | 1 GB |
| nlp-phi3-assistant | llama.cpp | Phi-3-Mini-4K-Instruct GGUF | Optional | 3 GB |
| demand-fcst-edge | ONNX Runtime | TFT-lite ONNX | No | 512 MB |
| pred-maint-monitor | ONNX Runtime | Isolation Forest ONNX | No | 128 MB |

### 3.4 PostgreSQL — Store Canonical Database

**Version:** PostgreSQL 16  
**HA Mode:** Patroni (active/standby) on Tier A stores; single instance on Tier B  

Tables (per store schema — see LLD-013 for full DDL):
- `transactions` — store-level transaction ledger
- `transaction_lines` — line items per transaction
- `inventory` — current stock levels
- `inventory_movements` — stock movement audit trail
- `loyalty_balances` — customer loyalty account balances
- `loyalty_transactions` — loyalty earn/burn history
- `offline_payment_tokens` — pending settlement tokens
- `sync_state` — per-POS sync vector clock
- `shift_records` — cashier shift open/close records

---

## 4. High Availability Architecture

### Store Tiers

| Store Tier | Description | Edge HA Config | POS Count |
|---|---|---|---|
| Tier A (Flagship) | High-volume, 24/7 flagship stores | Active + warm standby (2 nodes) | 10–50 |
| Tier B (Standard) | Standard stores | Single node | 2–10 |
| Tier C (Small) | Kiosks / small format | No edge (POS-only mode) | 1 |

### Tier A Failover
```
Primary Edge Node active (K3s master + PG primary)
    │ PostgreSQL streaming replication (synchronous for financial data)
Secondary Edge Node standby (K3s worker + PG replica)
    │
Failure detection: Keepalived VRRP (1 second heartbeat)
Failover trigger: 3 consecutive missed heartbeats (3 seconds)
Patroni: promotes PG replica → PG primary (< 10 seconds)
K3s: standby assumes master role
VIP: MetalLB virtual IP re-assigned to standby
Total failover: < 30 seconds
POS terminals: automatically re-connect to VIP
```

---

## 5. Connectivity Management

### 5.1 WAN Connectivity

```
Primary: MPLS / Broadband (ISP dedicated line)
Failover: 4G/5G USB modem / PCIe cellular module (Cradlepoint / Sierra Wireless)

Failover trigger: Azure IoT Hub ping (TCP 443) fails for 30 seconds
Failover mechanism: ip route metric switching (Linux network namespaces)
Failback: automatic when primary link restored (5-minute hysteresis)
```

### 5.2 Connectivity State Machine

```
ONLINE_PRIMARY    ──[primary link fail]──► FAILOVER_CELLULAR
FAILOVER_CELLULAR ──[primary restored]──► ONLINE_PRIMARY (5min hysteresis)
ONLINE_PRIMARY    ──[both links fail]──►  STORE_OFFLINE
STORE_OFFLINE     ──[any link restored]──► SYNC_RECOVERY
SYNC_RECOVERY     ──[sync ACK complete]──► ONLINE_PRIMARY
```

---

## 6. GitOps Deployment

```
Azure DevOps Repo (store-edge-config)
    │
Flux v2 (running in K3s cluster) polls repo every 60 seconds
    │
HelmRelease / Kustomization resources applied
    │
Service images pulled from Azure Container Registry (ACR)
    │
Canary deployments: Flagger (10% → 50% → 100% with automated rollback)
```

### IoT Edge Module Deployment

```
Azure ML: new model trained + validated → pushed to ACR
Azure IoT Hub: deployment manifest updated (edge/modules config)
IoT Edge runtime on store node: manifest diff detected
Edge agent pulls new module container from ACR
Module health probe: 60-second startup timeout
Success: old module stopped, new module running
Failure: automatic rollback to previous module version
```

---

## 7. Security Controls

| Control | Implementation |
|---|---|
| Node Identity | X.509 device certificate in IoT Hub registry |
| K3s API | kubeconfig with client cert; no public exposure |
| Service Mesh | Linkerd (mTLS between K3s pods) |
| Secrets | Azure Key Vault pre-fetched at startup + local encrypted cache |
| Disk Encryption | LUKS full-disk encryption (AES-256-XTS) |
| Network | iptables: deny all inbound except LAN (POS) and defined WAN ports |
| Monitoring | Defender for Endpoint + Falco (runtime container security) |
| Physical | Tamper-evident case; TPM 2.0 boot chain validation |

---

## 8. Observability

| Signal | Tool | Destination |
|---|---|---|
| Metrics | Prometheus (scrapes all K3s pods + PG + Kafka) | Grafana local + Azure Monitor |
| Logs | Fluent Bit (DaemonSet) | Azure Log Analytics per tenant |
| Traces | OpenTelemetry Collector | Azure Application Insights |
| IoT Telemetry | IoT Edge telemetry module | Azure IoT Hub → Azure Data Explorer |
| Alerts | Grafana Alertmanager | PagerDuty + Store Manager app |

---

## 9. Related Documents

| Document | Reference |
|---|---|
| Store Edge Orchestration LLD | `02_LLD/LLD-003_Store_Edge_Orchestration.md` |
| Event Sync CRDT Engine LLD | `02_LLD/LLD-011_Event_Sync_CRDT_Engine.md` |
| Offline Architecture HLD | `01_HLD/HLD-010_Offline_Architecture.md` |
| MLOps Pipeline Design LLD | `02_LLD/LLD-015_MLOps_Pipeline_Design.md` |
