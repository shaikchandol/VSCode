# AI Inference API Specification
## EnterpriseRetailAI · AI Services REST API Reference

---

| Document | AI_Inference_API_Spec | Version | v1.0 | Status | Approved | Date | June 2026 |

---

## Overview

Base URL: `https://api.retailai.com/ai/v1`  
Auth: Bearer JWT (AAD OAuth2, tenant-scoped)  
All AI endpoints enforce per-tenant model isolation — a franchisee's model is never used for another tenant's inference.

---

## 1. Fraud Detection

### POST /fraud/score
Real-time fraud scoring for a POS transaction.

**Request:**
```json
{
  "transaction_id":   "uuid",
  "tenant_id":        "franchisee_042",
  "store_id":         "uuid",
  "pos_id":           "uuid",
  "features": {
    "amount_gbp":               27.40,
    "line_count":               4,
    "quantity_total":           6,
    "discount_pct":             0.073,
    "high_value_item_flag":     false,
    "cash_payment_flag":        false,
    "split_tender_flag":        false,
    "return_in_basket_flag":    false,
    "hour_of_day":              14,
    "day_of_week":              2,
    "is_opening_hour":          false,
    "is_closing_hour":          false,
    "card_bin_country_mismatch":false,
    "card_type_encoded":        1,
    "is_new_card_at_store":     false,
    "pos_error_rate_1h":        0.003,
    "cashier_tx_count_1h":      23,
    "offline_mode_flag":        false
  },
  "tier":             1
}
```

**Response 200:**
```json
{
  "transaction_id":  "uuid",
  "score":           0.12,
  "decision":        "ALLOW",
  "reason_codes":    [],
  "model_version":   "fraud-detect-v2.4.1",
  "inference_ms":    38,
  "tier_used":       1
}
```

**Decision values:** `ALLOW` (< 0.40) | `STEP_UP` (0.40–0.70) | `DECLINE` (> 0.70)

**Response 200 — step-up example:**
```json
{
  "score":        0.58,
  "decision":     "STEP_UP",
  "reason_codes": ["CARD_BIN_COUNTRY_MISMATCH", "HIGH_VELOCITY_1H"],
  "model_version":"fraud-detect-v2.4.1",
  "inference_ms": 41
}
```

---

### POST /fraud/feedback
Submit labelled outcome to feed model retraining pipeline.

**Request:**
```json
{
  "transaction_id":  "uuid",
  "original_score":  0.58,
  "label":           "FALSE_POSITIVE",   // TRUE_FRAUD | FALSE_POSITIVE | UNKNOWN
  "chargeback_ref":  null,
  "reported_by":     "store_manager_uuid"
}
```

**Response 202:** Accepted for async processing.

---

## 2. Demand Forecasting

### POST /forecast
Generate demand forecast for specified SKUs.

**Request:**
```json
{
  "store_id":       "uuid",
  "sku_ids":        ["sku_001", "sku_042"],
  "horizon_days":   [7, 14, 30],
  "as_of_date":     "2026-06-11",
  "include_feature_importance": true
}
```

**Response 200:**
```json
{
  "generated_at":   "2026-06-11T06:00:00Z",
  "model_version":  "tft_v3.1.0",
  "forecasts": [
    {
      "sku_id":     "sku_001",
      "sku_name":   "Organic Whole Milk 2L",
      "store_id":   "uuid",
      "7d":  { "p10": 42, "p50": 61,  "p90": 83  },
      "14d": { "p10": 88, "p50": 124, "p90": 167 },
      "30d": { "p10": 190,"p50": 268, "p90": 351 },
      "feature_importance": {
        "rolling_14d_avg":   0.28,
        "day_of_week":       0.19,
        "promotion_active":  0.14,
        "avg_temp_c":        0.09
      }
    }
  ],
  "inference_ms":   1847
}
```

### GET /forecast/replenishment?store_id={uuid}&horizon_days=14
Returns pre-computed replenishment suggestions from nightly batch run.

```json
// Response 200
{
  "store_id":  "uuid",
  "as_of":     "2026-06-11",
  "suggestions": [
    {
      "sku_id":         "sku_001",
      "sku_name":       "Organic Whole Milk 2L",
      "current_stock":  8,
      "forecast_p50":   124,
      "forecast_p90":   167,
      "order_qty":      159,
      "priority":       "URGENT"
    }
  ]
}
```

---

## 3. Personalised Promotions

### POST /promotions/rank
AI-rank eligible promotions for a given basket and customer context.

**Request:**
```json
{
  "basket": {
    "lines": [
      { "sku_id": "sku_001", "quantity": 2, "amount_minor": 300 },
      { "sku_id": "sku_042", "quantity": 1, "amount_minor": 1599 }
    ],
    "total_minor":        2740,
    "currency":           "GBP",
    "is_loyalty_member":  true,
    "loyalty_id":         "CUST-12345"
  },
  "pos_context": {
    "store_id":     "uuid",
    "hour_of_day":  14,
    "day_of_week":  2,
    "weather_code": "sunny",
    "pos_mode":     "online"
  },
  "candidate_promo_ids": ["promo_001","promo_042","promo_055"]
}
```

**Response 200:**
```json
{
  "ranked_promotions": [
    {
      "promo_id":              "promo_042",
      "name":                  "20% off dairy",
      "discount_type":         "pct",
      "discount_value":        20.0,
      "estimated_saving_minor": 490,
      "ai_score":              0.87,
      "reason":                "Your weekly dairy shop — save 20% today!"
    }
  ],
  "is_personalised":  true,
  "model_version":    "bandit_v1.8.0",
  "inference_ms":     84
}
```

### POST /promotions/outcome
Record promotion accept/decline outcome (bandit reward signal).

```json
// Request
{
  "promo_id":       "promo_042",
  "loyalty_id":     "CUST-12345",
  "outcome":        "REDEEMED",    // REDEEMED | DECLINED | VIEWED
  "basket_value_minor": 2740,
  "session_id":     "uuid"
}
```

---

## 4. NLP Store Assistant

### POST /assistant/query
Submit a natural language query to the store assistant.

**Request:**
```json
{
  "session_id":  "uuid",
  "query":       "Where is the milk and do you have any offers on it today?",
  "language":    "en-GB",
  "store_id":    "uuid",
  "customer_id": null
}
```

**Response 200 (Server-Sent Events — streaming):**
```
data: {"text_chunk": "Our organic whole milk", "is_final": false, "session_id": "uuid"}
data: {"text_chunk": " is in aisle 3.", "is_final": false}
data: {"text_chunk": " We have 20% off all dairy today!", "is_final": true, "intent": "product_search+promotion_info", "model": "gpt-4o"}
event: action_card
data: {"type": "promotion", "payload": {"promo_id": "promo_042", "name": "20% off dairy", "saving_minor": 490}}
```

### POST /assistant/voice
Submit audio for transcription + query resolution.

**Request:** `multipart/form-data` with `audio` (WebM/WAV) + `store_id` + `language_hint`

**Response 200:**
```json
{
  "transcript":   "Where is the milk?",
  "response_text":"Our whole milk is in aisle 3.",
  "response_audio_url": "https://tts.retailai.com/audio/resp_uuid.mp3",
  "intent":       "product_search"
}
```

---

## 5. Predictive Maintenance

### POST /maintenance/score
Score a device telemetry snapshot for failure prediction.

**Request:**
```json
{
  "device_id":   "POS-STORE001-T01",
  "tenant_id":   "franchisee_042",
  "telemetry_window_hours": 24,
  "features": {
    "cpu_usage_mean":        23.4,
    "cpu_temp_max":          58.1,
    "memory_used_max":       3200,
    "disk_free_min":         38.1,
    "printer_roller_cycles": 142850,
    "scanner_error_rate":    0.61,
    "card_reader_fail_rate": 0,
    "touch_response_max":    52,
    "latency_mean":          12.3,
    "packet_loss_mean":      0.0,
    "offline_events":        0,
    "tx_error_rate":         0,
    "sync_queue_max":        0,
    "uptime_hours":          1247.5
  }
}
```

**Response 200:**
```json
{
  "device_id":    "POS-STORE001-T01",
  "model_version":"pred-maint-v1.3.0",
  "anomaly_score":0.04,
  "failure_predictions": [
    {
      "component":        "thermal_printer",
      "failure_prob_72h": 0.71,
      "severity":         "WARNING",
      "recommended_action": "Schedule roller replacement and cleaning"
    }
  ],
  "inference_ms": 28
}
```

### GET /maintenance/schedule?tenant_id={uuid}&store_id={uuid}
Returns upcoming predicted maintenance events across all devices in a store.

---

## 6. Model Registry (Read-only)

### GET /models?tenant_id={uuid}&use_case={fraud|demand|promo|cv|nlp|maintenance}
List deployed models for a tenant.

```json
// Response 200
{
  "models": [
    {
      "model_id":       "uuid",
      "use_case":       "fraud",
      "version":        "2.4.1",
      "deployment_targets": ["cloud","edge","pos"],
      "deployed_at":    "ISO8601",
      "kpi_metrics": { "auc": 0.984, "tpr_at_fpr_02": 0.961 },
      "sha256":         "a3f4c2..."
    }
  ]
}
```

### GET /models/{model_id}/model-card
Returns the full model card for governance and explainability.

---

## 7. Rate Limits & Quotas

| Endpoint | Rate Limit | Monthly Quota |
|---|---|---|
| `/fraud/score` | 2000 req/s per tenant | Unlimited |
| `/forecast` | 50 req/s per tenant | 500,000 req/month |
| `/promotions/rank` | 200 req/s per tenant | 10M req/month |
| `/assistant/query` | 50 req/s per tenant | 1M tokens/month |
| `/assistant/voice` | 20 req/s per tenant | 100,000 min/month |
| `/maintenance/score` | 100 req/s per tenant | Unlimited |

Quota overages return `HTTP 429` with `Retry-After` and upgrade instructions.

---

## 8. Related Documents
- HLD-005: AI/ML Platform
- LLD-004: Fraud Detection Service
- LLD-005: Demand Forecasting Pipeline
- LLD-006: Personalisation Engine
- LLD-008: NLP Store Assistant
- LLD-009: Predictive Maintenance
- LLD-014: API Design
