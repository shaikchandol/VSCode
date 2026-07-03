# HLD-004 — Cloud Platform (Azure)
## EnterpriseRetailAI · Azure Cloud Architecture

---

| Attribute | Value |
|---|---|
| Document ID | HLD-004 |
| Type | High-Level Design |
| Version | 1.0 |
| Status | Approved |
| Date | June 2026 |

---

## 1. Purpose

This document defines the high-level design of the Azure cloud platform that powers the EnterpriseRetailAI backend — including AKS microservice clusters, API Management, data stores, event streaming, and the global networking topology.

---

## 2. Azure Platform Architecture

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                     AZURE GLOBAL PLATFORM TOPOLOGY                         ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  GLOBAL TIER                                                                 ║
║  ┌────────────────────────────────────────────────────────────────────────┐  ║
║  │  Azure Front Door Premium                                             │  ║
║  │  ├ Global WAF (OWASP 3.2 + custom rules)                             │  ║
║  │  ├ CDN (static assets — POS config, model bundles)                   │  ║
║  │  ├ Health-based routing (latency + availability)                     │  ║
║  │  └ DDoS Protection Standard                                          │  ║
║  └──────────────────────────────────┬─────────────────────────────────────┘  ║
║                                     │                                        ║
║  ┌────────────────────────────────────────────────────────────────────────┐  ║
║  │  Azure API Management (Premium — multi-region gateway)                │  ║
║  │  ├ Products: POS API, Store Admin API, Franchisee API, HQ API        │  ║
║  │  ├ Policies: tenant JWT validation, rate limiting, quota             │  ║
║  │  ├ Developer Portal (franchisee API docs)                            │  ║
║  │  └ Analytics: per-tenant API usage reporting                         │  ║
║  └───────────────┬─────────────────────────────┬───────────────────────────┘  ║
║                  │                             │                              ║
║  REGIONAL TIER (example: EU West Region)                                      ║
║  ┌───────────────▼─────────────────────────────▼───────────────────────────┐  ║
║  │         AKS CLUSTER (Germany West Central — EU Primary)               │  ║
║  │                                                                        │  ║
║  │  System Node Pool: 3× Standard_D4s_v5 (12 vCPU, 48GB) — HA          │  ║
║  │  App Node Pool: 3–20× Standard_D8s_v5 (auto-scale) — workloads      │  ║
║  │  GPU Node Pool: 0–3× Standard_NC6s_v3 (ML inference, on-demand)     │  ║
║  │                                                                        │  ║
║  │  ┌──────────────────── NAMESPACES ─────────────────────────────────┐  │  ║
║  │  │                                                                 │  │  ║
║  │  │  NS: franchisee-{id} (one per active tenant in region)          │  │  ║
║  │  │  ┌────────────┐ ┌────────────┐ ┌─────────────┐ ┌────────────┐ │  │  ║
║  │  │  │POS API Svc │ │ Inventory  │ │  Loyalty    │ │  Payment   │ │  │  ║
║  │  │  │2 replicas  │ │ Service    │ │  Service    │ │  Service   │ │  │  ║
║  │  │  │HPA: 2–8    │ │ 2 replicas │ │ 2 replicas  │ │ 2 replicas │ │  │  ║
║  │  │  └────────────┘ └────────────┘ └─────────────┘ └────────────┘ │  │  ║
║  │  │  ┌────────────┐ ┌────────────┐ ┌─────────────┐               │  │  ║
║  │  │  │Promotion   │ │Report Svc  │ │ AI Proxy    │               │  │  ║
║  │  │  │Service     │ │(BI queries)│ │ Service     │               │  │  ║
║  │  │  └────────────┘ └────────────┘ └─────────────┘               │  │  ║
║  │  │                                                                 │  │  ║
║  │  │  NS: platform-shared (HQ-managed, cluster-wide)                │  │  ║
║  │  │  ┌────────────┐ ┌────────────┐ ┌─────────────┐ ┌────────────┐ │  │  ║
║  │  │  │Tenant Mgmt │ │Auth / IAM  │ │ Compliance  │ │ MLOps Orch │ │  │  ║
║  │  │  │Service     │ │ Service    │ │  Service    │ │  Service   │ │  │  ║
║  │  │  └────────────┘ └────────────┘ └─────────────┘ └────────────┘ │  │  ║
║  │  └─────────────────────────────────────────────────────────────────┘  │  ║
║  └────────────────────────────────────────────────────────────────────────┘  ║
║                                                                              ║
║  DATA TIER                                                                   ║
║  ┌───────────────────┐ ┌──────────────────┐ ┌───────────────────────────┐   ║
║  │ Azure SQL Flexible│ │ Azure Cosmos DB  │ │ Azure Redis Cache         │   ║
║  │ (per-tenant schema│ │ (product catalog │ │ (API response cache,      │   ║
║  │  up to 100 schemas│ │  global dist.)   │ │  session tokens,          │   ║
║  │  per server)      │ │                  │ │  promo rules cache)       │   ║
║  └───────────────────┘ └──────────────────┘ └───────────────────────────┘   ║
║                                                                              ║
║  MESSAGING TIER                                                              ║
║  ┌───────────────────┐ ┌──────────────────┐ ┌───────────────────────────┐   ║
║  │ Azure Event Hubs  │ │ Azure Service Bus│ │ Azure Event Grid          │   ║
║  │ (per-tenant ns)   │ │ (command msgs)   │ │ (platform events,         │   ║
║  │ Kafka endpoint    │ │ Premium tier     │ │  webhooks)                │   ║
║  └───────────────────┘ └──────────────────┘ └───────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 3. AKS Configuration

### 3.1 Cluster Specifications per Region

| Parameter | Value |
|---|---|
| Kubernetes Version | 1.29+ (auto-upgrade channel: stable) |
| Network Plugin | Azure CNI Overlay |
| Network Policy | Cilium (eBPF-based, per-namespace isolation) |
| Service Mesh | Istio 1.20 (mTLS, traffic management, observability) |
| Ingress | NGINX Ingress Controller + cert-manager (Let's Encrypt / DigiCert) |
| GitOps | Flux v2 (AKS extension) |
| Secrets Management | Azure Key Vault CSI Driver |
| Node Auto-provisioner | Azure Karpenter (node pool auto-scaling) |
| Node Image | Azure Linux (CBL-Mariner), CIS hardened |
| Private Cluster | ✅ — no public API server; Azure Bastion for admin |

### 3.2 HPA Configuration (Example — POS API Service)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: pos-api-hpa
  namespace: franchisee-042
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: pos-api-service
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 65
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 75
  - type: Pods
    pods:
      metric:
        name: pos_api_requests_per_second
      target:
        type: AverageValue
        averageValue: "500"
```

---

## 4. Data Platform Architecture

### 4.1 Azure SQL Flexible Server (Tenant Schemas)

```
Configuration:
  SKU: Business Critical (zone-redundant)
  vCores: 8–32 (autoscale with Azure SQL Hyperscale option for large tenants)
  Storage: 1TB initial, auto-grow enabled
  Backup: Point-in-time restore — 35 days retention
  HA: Zone-redundant with automatic failover (< 20 seconds RTO)
  Encryption: TDE with Customer-Managed Keys (per-tenant CMK in Key Vault)
  Network: Private Endpoint only (no public access)
  
Schema Provisioning:
  Max schemas per server: 100 franchisees
  Schema name pattern: tenant_{franchisee_id}
  Row-level security: enforced at DB user level (SET LOCAL app.tenant_id)
  Connection pooling: PgBouncer (sidecar in AKS, per-namespace)
```

### 4.2 Azure Cosmos DB (Product Catalogue)

```
Configuration:
  API: NoSQL (Core SQL)
  Consistency: Session (default) / Strong (price/promo critical reads)
  Replication: Multi-region writes (all platform regions)
  Partitioning: /tenantId for tenant-specific overrides; /sku for global
  
Collections:
  - products              (global catalogue, partitioned by /category)
  - tenant_product_overrides (per-franchisee price/promo/name overrides)
  - promotions_engine     (active promotions, TTL-enabled)
  - store_configurations  (store-level settings)
  
Caching: Redis L2 cache (15-min TTL for product lookups)
```

### 4.3 Azure Data Lake Gen2 (AI Training + Analytics)

```
Hierarchy:
  /{tenantId}/raw/transactions/year={Y}/month={M}/day={D}/
  /{tenantId}/curated/features/
  /{tenantId}/ml-training/demand-forecast/
  /{tenantId}/ml-training/fraud-detection/
  /platform/anonymised-benchmarks/    (cross-tenant, HQ only)

Access Control:
  RBAC: Storage Blob Data Contributor per tenant (managed identity per AKS ns)
  Encryption: Azure-managed keys (CMK option for regulated tenants)
  Lifecycle: Hot (0-30d) → Cool (31-90d) → Archive (91d+) → Delete (7y)
```

---

## 5. Event Streaming Architecture

### 5.1 Azure Event Hubs (per-tenant namespace)

```
Namespace: retail-events-{tenantId}.servicebus.windows.net

Event Hubs (topics):
  ├ transactions        (32 partitions, 7-day retention)
  ├ inventory-updates  (16 partitions, 3-day retention)
  ├ loyalty-events     (16 partitions, 3-day retention)
  ├ payment-events     (32 partitions, 7-day retention — PCI scope)
  ├ device-telemetry   (16 partitions, 3-day retention)
  └ audit-events       (8 partitions, 90-day retention)

Throughput: Standard 10 TU → Premium auto-inflate to 40 TU
Capture: Auto-capture to ADLS Gen2 (Avro format, 5-min windows)

Consumer Groups (per hub):
  ├ $Default
  ├ stream-analytics-consumer
  ├ ml-training-consumer
  ├ audit-consumer
  └ notification-consumer
```

### 5.2 Azure Stream Analytics (CRDT Merge)

```
Input: Event Hubs (transactions hub, per tenant)
Processing:
  - Deduplication by idempotency_key (24h window)
  - CRDT merge for inventory updates (last-write-wins by vector clock)
  - Late arrival handling: 5-minute watermark
  - Tumbling window aggregations: 1-min, 15-min, 1-hour sales
Output:
  - Azure SQL (canonical tenant schema)
  - Power BI streaming dataset (real-time dashboards)
  - ADLS Gen2 (ML training data)
  - Azure Service Bus (inventory alerts)

Parallelism: 6 SUs (scales to 192 SUs for peak)
```

---

## 6. Networking Architecture

### 6.1 Virtual Network Topology (EU Region Example)

```
Azure Virtual WAN Hub (Germany West Central)
│
├── Spoke VNet: AKS Cluster (10.10.0.0/16)
│   ├ AKS node subnet:     10.10.1.0/24
│   ├ AKS pod subnet:      10.10.2.0/23
│   └ AKS service subnet:  10.10.4.0/24
│
├── Spoke VNet: Data Services (10.20.0.0/16)
│   ├ Azure SQL PE subnet: 10.20.1.0/24
│   ├ Cosmos DB PE subnet: 10.20.2.0/24
│   ├ Redis PE subnet:     10.20.3.0/24
│   └ Event Hubs PE:       10.20.4.0/24
│
├── Spoke VNet: Management (10.30.0.0/24)
│   ├ Bastion host:        10.30.0.0/27
│   └ DevOps agents:       10.30.0.64/26
│
└── VPN Gateway / ExpressRoute (store edge connection)
    └── Store edge nodes connect via VPN or ExpressRoute
```

### 6.2 Private Endpoints (All Data Services)

All PaaS services use Private Endpoints — no public internet exposure:
- Azure SQL Flexible Server → PE in Data Services VNet
- Cosmos DB → PE in Data Services VNet
- Azure Key Vault → PE in each spoke VNet
- Event Hubs → PE in Data Services VNet
- ACR (Azure Container Registry) → PE in AKS VNet
- Azure ML Workspace → PE in AKS VNet

### 6.3 TLS Configuration

```
Azure Front Door → APIM: TLS 1.3 (managed cert)
APIM → AKS: mTLS via Istio service mesh
AKS pod → Azure SQL: TLS 1.3 (enforce_tls = true)
AKS pod → Event Hubs: AMQP over TLS 1.3
AKS pod → Key Vault: TLS 1.3 (MSI auth — no secret required)
Store Edge → IoT Hub: TLS 1.3 + X.509 device cert
Store Edge → Event Hubs: AMQP TLS 1.3 + device cert
```

---

## 7. Azure Key Vault Strategy

```
Vault per tenant: kv-{tenantId}-{region}
  ├ DB connection strings (per service, per tenant)
  ├ Tenant CMK (database encryption key)
  ├ Event Hubs SAS keys
  ├ Payment tokenisation keys
  └ Service-to-service API keys

Vault for platform: kv-platform-{region}
  ├ Platform service principals
  ├ CI/CD pipeline secrets
  ├ Signing keys (model bundles, configs)
  └ Certificate authority (internal PKI)

Access Model:
  AKS workloads: Workload Identity (pod MSI) → no secrets in code
  CI/CD pipelines: Azure DevOps service connection → MSI
  Store edge: Pre-fetched at startup → local encrypted cache
  Rotation: Automatic for DB passwords (Key Vault rotation policy, 90 days)
```

---

## 8. Cost Optimisation Strategy

| Strategy | Implementation |
|---|---|
| AKS spot nodes | Non-critical batch workloads (ML training, reporting) on spot pools |
| Event Hubs auto-inflate | Scale down TUs in off-peak (midnight–6am) |
| Cosmos DB autoscale | RU/s scales with actual traffic (min 400 RU/s per collection) |
| Azure SQL serverless | Dev/staging environments only (production = provisioned) |
| Reserved instances | 3-year reserved for AKS nodes, SQL, Cosmos (committed tenants) |
| Data tiering | ADLS lifecycle: Hot → Cool → Archive (significant savings on training data) |
| Azure Spot for ML | Training pipelines run on spot compute (80% cost reduction) |

---

## 9. Related Documents

| Document | Reference |
|---|---|
| System Architecture Overview | `01_HLD/HLD-001_System_Architecture_Overview.md` |
| AI/ML Platform HLD | `01_HLD/HLD-005_AI_ML_Platform.md` |
| Data Architecture HLD | `01_HLD/HLD-006_Data_Architecture.md` |
| Security HLD | `01_HLD/HLD-007_Security_Compliance.md` |
| API Design LLD | `02_LLD/LLD-014_API_Design.md` |
| Data Schema LLD | `02_LLD/LLD-013_Data_Schema_Design.md` |
