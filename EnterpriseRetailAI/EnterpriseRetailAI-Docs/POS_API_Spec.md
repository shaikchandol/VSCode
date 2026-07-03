# POS Terminal API Specification
## EnterpriseRetailAI · OpenAPI 3.1 Reference

---

| Document | POS_API_Spec | Version | v1.0 | Status | Approved |

---

## Overview

Base URL: `https://api.retailai.com/pos/v1`  
Auth: Bearer JWT (device certificate-backed, issued by IoT Hub)  
Rate Limit: 1,000 req/s per device  
All monetary values: **integer minor currency units** (pence, cents, paisa)

---

## Authentication

```
Authorization: Bearer {device_jwt}
X-Device-ID: {pos_terminal_uuid}
X-Tenant-ID: {franchisee_uuid}      ← injected by APIM from JWT claim
Idempotency-Key: {uuid_v4}          ← required for all POST/PUT
```

---

## 1. Transactions

### POST /transactions
Submit a completed POS transaction.

**Request:**
```json
{
  "transaction_id":    "01HXYZ...",
  "store_id":          "uuid",
  "cashier_id":        "uuid",
  "shift_id":          "uuid",
  "opened_at":         "2026-06-11T10:00:00Z",
  "completed_at":      "2026-06-11T10:02:47Z",
  "currency":          "GBP",
  "subtotal_minor":    2450,
  "tax_total_minor":   490,
  "discount_total_minor": 200,
  "grand_total_minor": 2740,
  "payment_method":    "EMV_CHIP",
  "is_offline_tx":     false,
  "loyalty_id":        "CUST-12345",
  "applied_promos":    ["promo_042"],
  "vector_clock":      {"POS-T01": 1042},
  "lines": [
    {
      "line_id":          "uuid",
      "sku_id":           "sku_001",
      "barcode":          "5012345678900",
      "product_name":     "Organic Whole Milk 2L",
      "quantity":         2,
      "unit_price_minor": 150,
      "tax_amount_minor": 0,
      "discount_minor":   0,
      "line_total_minor": 300
    }
  ]
}
```

**Response 201:**
```json
{
  "transaction_id": "01HXYZ...",
  "sync_status": "ACCEPTED",
  "receipt_number": "RCP-20260611-0042"
}
```

**Response 409:** Already processed (idempotency key matched)
```json
{ "sync_status": "ALREADY_EXISTS", "original_receipt": "RCP-20260611-0042" }
```

---

### GET /transactions/{transaction_id}
Retrieve a single transaction.

**Response 200:**
```json
{
  "transaction_id":    "uuid",
  "store_id":          "uuid",
  "state":             "COMPLETE",
  "completed_at":      "ISO8601",
  "grand_total_minor": 2740,
  "currency":          "GBP",
  "lines":             [...],
  "payment_method":    "EMV_CHIP",
  "receipt_number":    "RCP-20260611-0042"
}
```

---

### GET /transactions
List transactions with cursor pagination.

**Query Params:** `store_id`, `from` (ISO8601), `to` (ISO8601), `cursor`, `limit` (max 100)

**Response 200:**
```json
{
  "data": [...],
  "cursor_next": "eyJ0aW1lc3RhbXAiOiAi...",
  "total_count": 1247
}
```

---

## 2. Products

### GET /products/{barcode}
Look up a product by barcode.

**Response 200:**
```json
{
  "sku_id":             "uuid",
  "barcode":            "5012345678900",
  "name":               "Organic Whole Milk 2L",
  "category":           "dairy",
  "base_price_minor":   150,
  "tax_category":       "zero",
  "weight_grams":       2050,
  "is_active":          true,
  "image_url":          "https://cdn.retailai.com/products/sku_001.jpg"
}
```

**Response 404:** Product not found — cashier should manually enter or request manager

---

### GET /products/search?q={term}&limit=10
Fuzzy search by name or partial barcode.

---

## 3. Promotions

### GET /promotions?store_id={uuid}&active_at={ISO8601}
Get active promotions for a store.

**Response 200:**
```json
{
  "promotions": [
    {
      "promo_id":       "promo_042",
      "name":           "20% off dairy — Tuesday special",
      "discount_type":  "pct",
      "discount_value": 20.0,
      "conditions": {
        "min_basket_minor": 1000,
        "applicable_categories": ["dairy"],
        "applicable_skus": []
      },
      "exclusive_group": "tuesday_dairy",
      "valid_from":     "2026-06-11T00:00:00Z",
      "valid_until":    "2026-06-11T23:59:59Z",
      "promo_version":  7
    }
  ],
  "valid_until": "2026-06-11T10:15:00Z"
}
```

### POST /promotions/rank
AI-rank eligible promotions for a basket.

**Request:**
```json
{
  "basket": {
    "lines":            [...],
    "total_minor":      2740,
    "is_loyalty_member": true,
    "loyalty_id":       "CUST-12345"
  },
  "pos_context": {
    "hour_of_day": 14,
    "day_of_week": 2,
    "weather_code": "cloudy",
    "pos_mode":    "online"
  }
}
```

**Response 200:**
```json
{
  "ranked_promotions": [
    {
      "promo_id":             "promo_042",
      "name":                 "20% off dairy",
      "discount_type":        "pct",
      "discount_value":       20.0,
      "estimated_saving_minor": 490,
      "ai_score":             0.87,
      "reason":               "Your weekly dairy shop — save 20% today!"
    }
  ],
  "is_personalised": true,
  "model_version":   "bandit_v1.8.0",
  "latency_ms":      84
}
```

---

## 4. Loyalty

### GET /loyalty/balance/{loyalty_id}
**Response 200:**
```json
{
  "account_id":     "uuid",
  "loyalty_number": "CUST-12345",
  "points_balance": 2340,
  "tier":           "GOLD",
  "tier_expires":   "2027-01-01",
  "next_tier":      "PLATINUM",
  "points_to_next": 660
}
```

### POST /loyalty/accrue
```json
// Request
{ "transaction_id": "uuid", "loyalty_id": "CUST-12345", "grand_total_minor": 2740, "currency": "GBP" }

// Response 201
{ "points_earned": 27, "new_balance": 2367, "tier_points_progress": 47 }
```

### POST /loyalty/redeem
```json
// Request
{ "transaction_id": "uuid", "loyalty_id": "CUST-12345", "points_to_redeem": 500 }

// Response 200
{ "points_redeemed": 500, "new_balance": 1867, "discount_minor": 500 }
```

---

## 5. Payment Tokens (Offline)

### POST /payments/token
Create an offline payment token (called when Store Edge payment gateway unavailable).

**Request:**
```json
{
  "transaction_id":  "uuid",
  "encrypted_pan":   "DUKPT_ENCRYPTED_BASE64",
  "ksn":             "FFFF9876543210E00008",
  "amount_minor":    2740,
  "currency":        "GBP",
  "card_type":       "EMV_CHIP",
  "shift_id":        "uuid"
}
```

**Response 201:**
```json
{
  "token_id":   "uuid",
  "status":     "PENDING",
  "expiry_at":  "2026-06-12T10:02:47Z",
  "ceiling_remaining_minor": 15000
}
```

**Response 402:** Ceiling exceeded
```json
{ "error": "OFFLINE_CEILING_EXCEEDED", "ceiling_minor": 15000, "shift_total_minor": 14800 }
```

---

## 6. Sync

### POST /sync/events
Bulk event relay from POS SQLite outbox.

**Headers:**
```
Content-Type: application/octet-stream
Content-Encoding: zstd
X-Batch-ID: {uuid}
X-Event-Count: 47
X-Vector-Clock: {"POS-T01":1042}
```

**Body:** AES-256-GCM encrypted, zstd-compressed NDJSON event batch

**Response 200:**
```json
{
  "acknowledged_ids":   ["id1", "id2"],
  "store_vector_clock": {"POS-T01": 1042, "STORE-EDGE": 15023},
  "backpressure_wait_ms": 0
}
```

---

## 7. Error Codes Reference

| HTTP Status | Error Code | Meaning |
|---|---|---|
| 400 | VALIDATION_ERROR | Request body failed validation |
| 401 | DEVICE_NOT_AUTHENTICATED | Invalid/expired device JWT |
| 403 | TENANT_MISMATCH | Device tenant ≠ JWT tenant claim |
| 404 | PRODUCT_NOT_FOUND | Barcode not in catalogue |
| 409 | IDEMPOTENCY_CONFLICT | Request already processed |
| 402 | OFFLINE_CEILING_EXCEEDED | Payment exceeds offline limit |
| 422 | BUSINESS_RULE_VIOLATION | Transaction state machine violation |
| 429 | RATE_LIMIT_EXCEEDED | Too many requests from device |
| 503 | SERVICE_UNAVAILABLE | Store Edge sync backpressure |
