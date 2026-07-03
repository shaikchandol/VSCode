# HLD-008 — Integration Architecture
## EnterpriseRetailAI · API Strategy, Event-Driven Integration, External Systems

| Document ID | HLD-008 | Version | 1.0 | Status | Approved | Date | June 2026 |

## 1. Integration Topology

SYNCHRONOUS: Azure APIM → POS API / Store API / Admin API / AI Inference API
ASYNCHRONOUS: Azure Event Hubs (transactions, inventory, loyalty, payments, telemetry)
COMMANDS: Azure Service Bus (replenishment, promotions, notifications, erasure)

## 2. APIM Products & Rate Limits

| Product | Rate Limit | Auth |
|---|---|---|
| POS Terminal API | 1000 req/s per device | X.509 + JWT |
| Store Management API | 100 req/s per store | AAD OAuth2 |
| Franchisee Admin API | 50 req/s per tenant | AAD OAuth2 + RBAC |
| HQ Platform API | Unlimited (internal) | AAD + PIM |
| Partner API | Per SLA | mTLS + API Key |
| AI Inference API | Model quota | JWT + tenant scope |

## 3. APIM Tenant Isolation Policy (all products)

Inbound: Validate JWT → extract tenant_id claim → inject X-Tenant-ID header → 
         apply per-tenant rate limit by X-Tenant-ID key

## 4. External Integrations

| System | Protocol | Direction | Auth |
|---|---|---|---|
| Adyen/Stripe | HTTPS + Webhook | Bi-directional | mTLS + API key |
| SAP ERP | REST + RFC | Bi-directional | OAuth2 + VPN |
| Salesforce CRM | REST Bulk API v2 | Bi-directional | OAuth2 PKCE |
| WMS (Manhattan) | REST + EDI | Bi-directional | mTLS |
| Avalara Tax | REST | Outbound | API key + TLS |
| Weather API | REST | Inbound | API key |
| FX Rate Service | REST | Inbound | API key |
| ServiceNow | REST | Outbound | OAuth2 |

## 5. Event Schema (CloudEvents v1.0 + Schema Registry)

All events use CloudEvents 1.0 spec. Avro schemas registered in Azure Schema Registry.
Breaking changes require new major version with 90-day backward compatibility window.

## 6. Saga: Replenishment Orchestration

Azure Durable Functions orchestrator:
Step 1: Get forecast (Azure ML endpoint)
Step 2: Get current stock (Inventory Service)
Step 3: Calculate reorder quantities
Step 4: Check supplier availability (ERP API)
Step 5: Create purchase order (SAP ERP)
Step 6: Notify store manager
Step 7: Set expected delivery in inventory

Compensation: if any step fails → alert procurement manager → manual intervention

## 7. Related Documents

- LLD-014: API Design
- LLD-011: Event Sync CRDT Engine
- LLD-012: Payment Service
