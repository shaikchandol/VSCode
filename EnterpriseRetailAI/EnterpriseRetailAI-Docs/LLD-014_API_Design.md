# LLD-014 — API Design
## EnterpriseRetailAI · REST + gRPC Specs, APIM Policies, Versioning, Rate Limits

---

| Document ID | LLD-014 | Version | 1.0 | Status | Approved | Date | June 2026 |

---

## 1. API Design Principles

1. **Resource-oriented REST** — URLs identify resources; HTTP verbs define actions
2. **Consistent versioning** — `v{major}` path prefix; minor versions via Accept header
3. **Tenant isolation** — every request carries validated `X-Tenant-ID` (APIM-injected)
4. **Idempotency** — all mutating POST endpoints accept `Idempotency-Key` header
5. **Pagination** — cursor-based for all list endpoints (no offset pagination)
6. **Error schema** — RFC 7807 Problem Details for all error responses
7. **gRPC for high-frequency** — IoT telemetry and store edge sync use gRPC + protobuf
8. **OpenAPI 3.1** — all REST APIs documented; auto-published to APIM Developer Portal

---

## 2. Common Headers

```
Request Headers:
  Authorization:     Bearer {JWT}      (required — all endpoints)
  X-Tenant-ID:       {tenant_uuid}     (injected by APIM; validated against JWT)
  Idempotency-Key:   {uuid_v4}         (required for POST/PUT mutations)
  Accept-Language:   en-GB             (optional; affects error message language)
  X-Correlation-ID:  {uuid}            (optional; propagated to all downstream calls)
  X-Device-ID:       {device_uuid}     (required for POS terminal API only)

Response Headers:
  X-Correlation-ID:  {uuid}            (echoed from request or generated)
  X-Request-ID:      {uuid}            (unique per response for debugging)
  X-RateLimit-Limit: 1000
  X-RateLimit-Remaining: 847
  X-RateLimit-Reset: 1749600060
```

---

## 3. Error Response Schema (RFC 7807)

```json
{
  "type":     "https://errors.retailai.com/validation-error",
  "title":    "Validation Error",
  "status":   400,
  "detail":   "The 'amount' field must be a positive integer in minor currency units.",
  "instance": "/api/v1/transactions/b8a3c1f2-...",
  "errors": [
    {
      "field":   "amount",
      "code":    "MUST_BE_POSITIVE",
      "message": "amount must be > 0"
    }
  ],
  "correlation_id": "a1b2c3d4-..."
}
```

---

## 4. POS Terminal API

### 4.1 Transactions

```yaml
POST /api/v1/transactions
Description: Submit a completed POS transaction event
Headers:
  Authorization: Bearer {POS_JWT}
  X-Tenant-ID: {tenant_id}
  X-Device-ID: {pos_id}
  Idempotency-Key: {uuid_v4}
Request Body:
  transaction_id:    string (uuid-v7)
  store_id:          string (uuid)
  cashier_id:        string (uuid)
  shift_id:          string (uuid)
  opened_at:         string (ISO8601)
  completed_at:      string (ISO8601)
  currency:          string (ISO 4217)
  grand_total_minor: integer
  payment_method:    string
  is_offline_tx:     boolean
  lines:             array[TransactionLine]
  applied_promos:    array[string]
  loyalty_id:        string | null
  vector_clock:      object

Response 201:
  transaction_id: string
  sync_status:    "ACCEPTED" | "ALREADY_EXISTS"

Response 409: already processed (idempotency hit)
Response 422: validation error
```

```yaml
GET /api/v1/transactions/{transaction_id}
Description: Retrieve a specific transaction
Response 200:
  transaction_id, store_id, state, completed_at,
  grand_total_minor, lines, payment_method, receipt_number

GET /api/v1/transactions?store_id=&from=&to=&cursor=&limit=50
Description: List transactions for a store with cursor pagination
Response 200:
  data: array[Transaction]
  cursor_next: string | null
  total_count: integer
```

### 4.2 Product Lookup

```yaml
GET /api/v1/products/{barcode}
Description: Look up product by barcode (UPC, EAN, QR)
Response 200:
  sku_id:        string
  name:          string
  category:      string
  base_price_minor: integer
  tax_category:  string
  weight_grams:  number | null
  is_active:     boolean

Response 404: product not found (cashier should manual-enter)
```

### 4.3 Promotions

```yaml
GET /api/v1/promotions?store_id=&active_at=
Description: Get active promotions for a store
Response 200:
  promotions: array[Promotion]
  valid_until: string (ISO8601) — cache TTL hint

POST /api/v1/promotions/rank
Description: AI-rank applicable promotions for a basket
Request: basket object + pos_context (see LLD-006)
Response 200: ranked_promotions array
```

### 4.4 Loyalty

```yaml
GET /api/v1/loyalty/balance/{loyalty_id}
Response 200:
  account_id:     string
  points_balance: integer
  tier:           string
  tier_expires:   string | null

POST /api/v1/loyalty/accrue
Request: { transaction_id, loyalty_id, transaction_total_minor, currency }
Response 201: { points_earned, new_balance }

POST /api/v1/loyalty/redeem
Request: { transaction_id, loyalty_id, points_to_redeem }
Response 200: { points_redeemed, new_balance, discount_minor }
```

### 4.5 Sync

```yaml
POST /api/v1/sync/events
Description: Bulk event sync from POS outbox to store edge
Content-Type: application/octet-stream
Content-Encoding: zstd
Headers: X-Event-Count, X-Batch-ID, X-Vector-Clock
Body: AES-256-GCM encrypted, zstd-compressed NDJSON events

Response 200:
  acknowledged_ids: array[string]
  store_vector_clock: object
  backpressure_wait_ms: integer

Response 429: backpressure — retry after indicated ms
```

---

## 5. Store Management API

```yaml
GET /api/v1/stores/{store_id}/status
Response 200:
  store_id:         string
  connectivity:     "ONLINE" | "OFFLINE" | "SYNC_RECOVERY"
  pos_terminals:    array[POSStatus]
  inventory_synced: boolean
  last_cloud_sync:  string

GET /api/v1/stores/{store_id}/inventory?sku_ids=&low_stock_only=
Response 200:
  inventory: array[InventoryItem]

POST /api/v1/stores/{store_id}/inventory/adjust
Request: { sku_id, quantity_delta, reason, adjusted_by }
Response 201: { new_quantity_on_hand }

GET /api/v1/stores/{store_id}/shifts?date=&cashier_id=
Response 200: shifts array

GET /api/v1/stores/{store_id}/reports/sales?from=&to=&group_by=hour|day
Response 200: sales_summary time-series array

GET /api/v1/stores/{store_id}/reports/end-of-day?date=
Response 200: EOD reconciliation report (PDF link + JSON summary)
```

---

## 6. AI Inference API

```yaml
POST /api/v1/ai/fraud/score
Description: Score a transaction for fraud risk
Request:
  transaction_id: string
  features:       object (tier-1 feature vector)
Response 200:
  score:       float (0.0–1.0)
  decision:    "ALLOW" | "STEP_UP" | "DECLINE"
  reason_codes: array[string]
  model_version: string
  inference_ms:  integer

POST /api/v1/ai/forecast
Description: Get demand forecast for SKUs
Request: store_id, sku_ids, horizon_days, as_of_date
Response 200: forecasts array (see LLD-005)

POST /api/v1/ai/assistant
Description: NLP store assistant query
Request:
  session_id:  string (uuid, TTL 30 min)
  query:       string (max 500 chars)
  language:    string (BCP-47)
  store_id:    string
Response 200 (Server-Sent Events — streaming):
  data: { text_chunk: string, is_final: boolean }
  [event: action_card] data: { type: "product|promotion", payload: object }
```

---

## 7. gRPC Service Definitions (Store Edge)

```protobuf
syntax = "proto3";
package retailai.store.v1;

service StoreOrchestrationService {
  rpc SubmitTelemetry (TelemetryBatch) returns (TelemetryAck);
  rpc SyncEvents      (EventBatch)     returns (SyncAck);
  rpc GetStoreStatus  (StoreRequest)   returns (StoreStatus);
  rpc StreamAlerts    (StoreRequest)   returns (stream Alert);
}

message TelemetryBatch {
  string  device_id  = 1;
  string  tenant_id  = 2;
  string  store_id   = 3;
  repeated DeviceTelemetry events = 4;
}

message DeviceTelemetry {
  string timestamp      = 1;
  float  cpu_usage_pct  = 2;
  float  cpu_temp_c     = 3;
  uint32 memory_used_mb = 4;
  float  disk_free_gb   = 5;
  float  latency_ms     = 6;
  float  packet_loss_pct = 7;
  string printer_status  = 8;
  string scanner_status  = 9;
  string card_reader_status = 10;
  uint32 tx_count_1h    = 11;
  uint32 sync_queue_depth = 12;
}

message TelemetryAck {
  bool   accepted = 1;
  string message  = 2;
}

message EventBatch {
  string batch_id   = 1;
  string device_id  = 2;
  string tenant_id  = 3;
  repeated bytes events = 4;    // Avro-encoded events
  map<string, uint64> vector_clock = 5;
}

message SyncAck {
  repeated string acknowledged_ids = 1;
  map<string, uint64> store_vector_clock = 2;
  uint32 backpressure_wait_ms = 3;
}
```

---

## 8. API Versioning Strategy

```
URL versioning: /api/v1/, /api/v2/ (major breaking changes only)
Header versioning: Accept: application/vnd.retailai.v2.1+json (minor versions)

Lifecycle policy:
  - Current:     fully supported + actively developed
  - Deprecated:  12-month notice; no new features
  - Sunset:      retired; returns 410 Gone with migration guide URL

Version compatibility window:
  - N-1 version always supported (stores may lag on updates)
  - Store edge / POS clients: auto-upgrade via GitOps / IoT Hub
  - Franchisee portals: must upgrade within 6 months of deprecation notice
```

---

## 9. APIM Policies Summary

```
Global policy (all APIs):
  ├ validate-jwt: check AAD token + expiry
  ├ set-header X-Tenant-ID from JWT claim
  ├ rate-limit-by-key per tenant
  ├ quota per product subscription
  ├ log-to-eventhub: all requests + responses (PCI-DSS req 10)
  └ cors: configured per product (POS = no CORS; Admin = specific origins)

POS API additional:
  ├ check-header X-Device-ID: validate device in IoT Hub registry
  └ ip-filter: allow only known store IP ranges (per tenant)

AI Inference API additional:
  ├ set-body: inject tenant_id into request body
  └ cache-lookup: GET forecasts cached 5 min in Redis
```

---

## 10. Related Documents

- HLD-008: Integration Architecture
- LLD-001: POS Transaction Engine
- LLD-003: Store Edge Orchestration
- LLD-006: Personalisation Engine (promo rank API)
