# SKILL.md — Integration Architecture & External System Design

**Skill Name:** integration-architecture

**Purpose:** Help AI agents understand how EnterpriseRetailAI integrates with external systems (ERP, WMS, CRM, FX rates, payment gateways), API design patterns, and event-driven integration strategies.

---

## When to Use This Skill

Use this skill when:
- **External system integration** — "How do we integrate with SAP ERP? Salesforce CRM?"
- **API design questions** — "What are the REST/gRPC design standards?"
- **Event-driven architecture** — "How do we decouple systems via events?"
- **Payment gateway integration** — "How do we tokenise payments securely?"
- **Data synchronization** — "How do we keep POS inventory in sync with WMS?"
- **API rate limiting** — "What are the quotas for each API?"
- **API versioning** — "How do we evolve APIs without breaking clients?"

Do NOT use this skill for:
- General system architecture (use [HLD-001](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md))
- Specific service implementation (use relevant LLD)
- Network/infrastructure (use [HLD-004](EnterpriseRetailAI-Docs/HLD-004_Cloud_Platform_Azure.md))

---

## Integration Architecture Overview

EnterpriseRetailAI integrates with four classes of external systems:

```
                    EnterpriseRetailAI Platform
                            |
        ┌───────────────────┼───────────────────┐
        |                   |                   |
    ┌───▼───┐           ┌───▼───┐          ┌───▼────┐
    │  ERP  │           │ Payments       │ Market Data │
    │ (SAP) │           │ (Verifone)     │ (FX Rates) │
    └───┬───┘           └───┬───┘        └───┬────┘
        |                   |                   |
        │  REST/gRPC        │  P2PE         │  REST
        │  Async Queues     │  Offline Q    │  Async
        │                   │                   │
        └───────────────────┼───────────────────┘
                            |
        ┌───────────────────┼───────────────────┐
        |                   |                   |
    ┌───▼───┐           ┌───▼────┐         ┌───▼───┐
    │ WMS   │           │  CRM   │         │Market │
    │(3PL) │           │(SFDC)  │         │Data  │
    └───────┘           └────────┘         └──────┘
```

**Integration Methods:**
1. **REST APIs** — Synchronous, request-response
2. **gRPC** — High-performance streaming
3. **Event Hubs** — Asynchronous, pub-sub
4. **Offline Queues** — Retry with guaranteed delivery
5. **Webhooks** — Push notifications from external systems

**Reference:** [HLD-008_Integration_Architecture.md](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md), [LLD-014_API_Design.md](EnterpriseRetailAI-Docs/LLD-014_API_Design.md)

---

## External Systems Integrated

### 1. ERP System (SAP)

**Purpose:** Master data (products, pricing, cost center accounting)

**Integration Points:**
- **Products:** Daily batch sync of SKU master, pricing, hierarchies
- **Cost Centers:** Real-time lookup during transactions
- **GL Posting:** Daily batch of transaction summaries for accounting

**API Protocol:** REST with async acknowledgment
- Endpoint: `https://hq-sap.company.com/ords/products`
- Method: GET (query products) / POST (acknowledge receipt)
- Auth: OAuth 2.0 + API key
- Rate Limit: 1,000 req/min

**Offline Handling:**
- Store Edge caches product master locally
- POS uses cached data for 7 days (stale data warning after 24h)
- Sync resumes when connectivity restored

**Reference:** [HLD-008_Integration_Architecture.md](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md)

### 2. WMS System (3PL)

**Purpose:** Inventory synchronization

**Integration Points:**
- **Stock Levels:** Real-time push from WMS → Store Edge (every 1 hour batch)
- **Replenishment:** Store Edge submits orders to WMS
- **Receiving:** WMS confirms stock received at store

**API Protocol:** gRPC with exactly-once delivery guarantees
- Service: `InventoryService.SyncStock()`
- Auth: mTLS (mutual TLS with certificates)
- Rate Limit: Streaming (no rate limit, connection-oriented)

**Offline Handling:**
- Store Edge queues replenishment orders (PostgreSQL)
- WMS processes queued orders when connection restored
- Idempotency via order_id + timestamp

**Reference:** [HLD-008_Integration_Architecture.md](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md)

### 3. CRM System (Salesforce)

**Purpose:** Customer data, loyalty programs, marketing

**Integration Points:**
- **Customer Master:** Sync customer records (name, email, phone, tier)
- **Transactions:** Post transaction summaries for analytics
- **Loyalty:** Query customer points, apply rewards

**API Protocol:** REST with Salesforce OAuth + SOAP fallback
- Endpoint: `https://instance.salesforce.com/services/data/v57.0/`
- Auth: OAuth 2.0 (refresh token)
- Rate Limit: 15,000 API calls / 24 hours (org-wide)

**Offline Handling:**
- Store Edge has read-only customer cache (updated daily)
- POS shows cached loyalty balance
- Sync to Salesforce happens in batch during low-traffic hours

**Reference:** [HLD-008_Integration_Architecture.md](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md)

### 4. Payment Gateway (Verifone / PAX)

**Purpose:** Card payment processing

**Integration Points:**
- **Online Payments:** Real-time card authorization
- **Offline Payments:** Queue transaction, validate on reconnect
- **Settlement:** Daily batch settlement and reconciliation

**Protocol:** P2PE (Point-to-Point Encryption) with token vault
- Communication: Encrypted P2PE SDK (no card data in POS)
- Auth: Certificate pinning + HMAC signing
- Offline Queue: Local SQLite queue (retry on reconnect)

**Offline Handling:**
- POS tokenises card via P2PE device (hardware)
- Token stored locally (POS never sees card data)
- Transaction queued for authorization
- Upon reconnect: Batch authorization attempt
- Reconciliation: Daily settlement for all approved tokens

**Reference:** [ADR-007_P2PE_Payment.md](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md), [LLD-012_Payment_Service.md](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md)

### 5. Market Data (FX Rates, Commodity Prices)

**Purpose:** Dynamic pricing based on market conditions

**Integration Points:**
- **FX Rates:** Real-time or 15-min delayed rates for multi-currency pricing
- **Commodity Prices:** Cost adjustments for fuel, metals, etc.

**API Protocol:** REST with JSON response
- Endpoint: `https://api.fxdata.com/rates` (vendor-specific)
- Auth: API key in header
- Rate Limit: 1,000 req/day (bundled)

**Offline Handling:**
- Store Edge caches latest rates (updates hourly)
- POS uses cached rates (warning if >24h stale)
- Sync resumes automatically when connection restored

---

## API Design Standards

All APIs follow [LLD-014_API_Design.md](EnterpriseRetailAI-Docs/LLD-014_API_Design.md) standards:

### 1. **REST API Structure**

```
Endpoint: /api/{version}/{resource}/{id}/{subresource}
Version: v1, v2, v3, ... (breaking changes trigger new version)
Methods: GET, POST, PUT, DELETE, PATCH
Status Codes:
  ├─ 2xx: Success (200, 201, 204)
  ├─ 4xx: Client error (400, 401, 403, 404)
  └─ 5xx: Server error (500, 503)

Example:
  GET /api/v1/transactions/TX-12345
  POST /api/v1/transactions (create)
  PUT /api/v1/transactions/TX-12345 (update)
```

### 2. **gRPC Service Structure**

```protobuf
service ProductService {
  rpc GetProduct(GetProductRequest) returns (ProductResponse) {}
  rpc ListProducts(ListRequest) returns (stream ProductResponse) {}
  rpc SyncProducts(stream ProductEvent) returns (SyncResponse) {}
}
```

### 3. **Authentication & Authorization**

| Auth Type | Use Case | Standard |
|---|---|---|
| OAuth 2.0 | Third-party integrations (SAP, Salesforce, payment gateways) | RFC 6749 |
| API Key | Internal services, external SaaS | Custom header or query param |
| mTLS | High-security gRPC (WMS) | TLS 1.3, certificate pinning |
| JWT Token | POS ↔ Store Edge, Store Edge ↔ Cloud | RS256 (signed) |

### 4. **Rate Limiting & Quotas**

| API | Limit | Backoff |
|---|---|---|
| **POS API** | 1,000 req/sec per store | Exponential backoff (2^n sec) |
| **Store Management API** | 100 req/sec per store | 429 with Retry-After header |
| **Tenant Admin API** | 10 req/sec per tenant | 429 (quota reset hourly) |
| **AI Inference API** | 100 req/sec per store | 429 (queue in Store Edge) |

### 5. **API Versioning Strategy**

**Semantic Versioning:**
```
v1 (stable)
├─ v1.0: Initial release
├─ v1.1: Add optional fields (backward compatible)
├─ v1.2: Add deprecation warnings
└─ v1.3: Mark fields as deprecated (still supported)

v2 (breaking changes)
├─ v2.0: Remove deprecated fields, rename endpoints
└─ Coexist with v1 for 12 months (migration period)
```

**Reference:** [LLD-014_API_Design.md](EnterpriseRetailAI-Docs/LLD-014_API_Design.md)

---

## Event-Driven Integration Pattern

### Publisher-Subscriber Model

```
Event Producers:
├─ POS Terminal (transactions, inventory events)
├─ Store Edge (sync events, health checks)
└─ Cloud (config updates, model retraining)

                    ↓ (events)

Azure Event Hubs (distributed message broker)
├─ Topic: transactions
├─ Topic: inventory
├─ Topic: config
└─ Topic: models

                    ↓ (consume)

Event Consumers:
├─ Azure Stream Analytics (real-time analytics)
├─ Azure Functions (serverless processing)
├─ External systems (ERP, WMS, CRM via webhooks)
└─ Cloud data warehouse (batch ETL)
```

**Advantages:**
- ✅ Decoupled systems (no direct dependencies)
- ✅ Async processing (non-blocking)
- ✅ Replay capability (all events logged)
- ✅ Scalability (parallel consumers)

**Challenges:**
- ❌ Eventual consistency (not immediate)
- ❌ Duplicate handling (must be idempotent)
- ❌ Ordering (guaranteed per partition only)

**Reference:** [HLD-008_Integration_Architecture.md](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md)

---

## Integration Patterns by Scenario

| Scenario | Pattern | Example |
|---|---|---|
| **Sync Product Master** | Scheduled batch REST | Daily sync from SAP to Store Edge (cron job) |
| **Real-time Authorization** | Synchronous REST | Payment authorization from Verifone |
| **Inventory Sync** | gRPC streaming | Continuous stock level sync from WMS |
| **Promotional Events** | Event-driven (Event Hubs) | When promo starts, publish event → all stores notified |
| **Customer Updates** | Async queue + webhook | Salesforce customer update → queue → eventually sync to POS |
| **Model Deployment** | Webhooks + SFTP | Cloud publishes model ready → Store Edge pulls ONNX from SFTP |
| **Offline Resilience** | Local queue + retry | POS stores payment token → retries on reconnect |

---

## Reference Map

| Question | Document |
|---|---|
| Integration architecture overview? | [HLD-008_Integration_Architecture.md](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md) |
| API design standards? | [LLD-014_API_Design.md](EnterpriseRetailAI-Docs/LLD-014_API_Design.md) |
| POS API spec? | [POS_API_Spec.md](EnterpriseRetailAI-Docs/POS_API_Spec.md) |
| Store Management API spec? | [Store_Management_API_Spec.md](EnterpriseRetailAI-Docs/Store_Management_API_Spec.md) |
| Tenant Admin API spec? | [Tenant_Admin_API_Spec.md](EnterpriseRetailAI-Docs/Tenant_Admin_API_Spec.md) |
| AI Inference API spec? | [AI_Inference_API_Spec.md](EnterpriseRetailAI-Docs/AI_Inference_API_Spec.md) |
| Payment integration? | [LLD-012_Payment_Service.md](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md) |
| P2PE details? | [ADR-007_P2PE_Payment.md](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md) |

---

## Tips for Agents

1. **Identify the system** — Map the external system (ERP, WMS, CRM, payment, FX)
2. **State the integration method** — REST, gRPC, Event Hubs, offline queue, webhook
3. **Mention offline handling** — How does it work when POS/Store is offline?
4. **Reference the API spec** — Link to the relevant *_API_Spec.md
5. **Cite design standards** — Explain auth, rate limits, versioning (from LLD-014)
6. **Show the flow** — Walk through a complete integration scenario (request → response → offline handling)

---

## When You Don't Know the Answer

If a user asks about integration with a system not documented:
1. Check if a similar integration exists (ERP is like WMS in structure)
2. Apply the documented patterns (REST for sync, gRPC for streaming, Event Hubs for async)
3. Reference the API design standards (LLD-014)
4. Note this as a gap in documentation (future integration spec needed)
