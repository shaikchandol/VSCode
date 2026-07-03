# HLD-002 — POS Application
## EnterpriseRetailAI · Point-of-Sale Application Platform

---

| Attribute | Value |
|---|---|
| Document ID | HLD-002 |
| Type | High-Level Design |
| Version | 1.0 |
| Status | Approved |
| Date | June 2026 |

---

## 1. Purpose

This document defines the high-level design of the POS application layer — the software running on physical POS terminals (Windows .NET and Android) and self-checkout kiosks. It covers the module architecture, offline capabilities, AI integration, payment processing, and the synchronisation strategy.

---

## 2. POS Application Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                  POS APPLICATION — MODULE MAP                       │
│                                                                      │
│  PRESENTATION LAYER                                                  │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Windows: WPF/WinUI 3       Android: Jetpack Compose        │    │
│  │  ├ Cashier Screen           ├ Cashier Screen (touch)        │    │
│  │  ├ Customer-Facing Display  ├ Customer Display (2nd screen) │    │
│  │  ├ Manager Dashboard        ├ Manager App (tablet)          │    │
│  │  └ Self-Checkout UI         └ Self-Checkout (kiosk mode)    │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                           │                                          │
│  APPLICATION LAYER                                                   │
│  ┌─────────────────┐ ┌────────────────┐ ┌──────────────────────┐    │
│  │ Transaction     │ │ Promotion &    │ │  Payment Handler     │    │
│  │ Engine          │ │ Pricing Engine │ │                      │    │
│  │                 │ │                │ │  ├ Online (gateway)  │    │
│  │ ├ Basket Mgmt   │ │ ├ Price rules  │ │  ├ Offline (token)   │    │
│  │ ├ Item scan     │ │ ├ Promo rules  │ │  ├ P2PE encrypt      │    │
│  │ ├ Tax calc      │ │ ├ AI promo     │ │  └ Verifone/PAX SDK  │    │
│  │ ├ Discount      │ │ │  ranking     │ │                      │    │
│  │ ├ Return/Void   │ │ └ Loyalty calc │ └──────────────────────┘    │
│  │ └ Shift Mgmt    │ └────────────────┘                             │
│  └─────────────────┘                                                 │
│                                                                      │
│  ┌─────────────────┐ ┌────────────────┐ ┌──────────────────────┐    │
│  │ AI Module       │ │ Receipt        │ │  Sync Agent          │    │
│  │                 │ │ Service        │ │                      │    │
│  │ ├ Fraud ONNX    │ │                │ │  ├ Event Outbox      │    │
│  │ ├ Promo ONNX    │ │ ├ Print (USB)  │ │  ├ Store Edge relay  │    │
│  │ └ CV item recog │ │ ├ Email/SMS    │ │  ├ Retry backoff     │    │
│  │   (kiosk only)  │ │ └ QR code      │ │  └ ACK tracking      │    │
│  └─────────────────┘ └────────────────┘ └──────────────────────┘    │
│                           │                                          │
│  DATA LAYER                                                          │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  SQLite 3.44 (primary local store)                         │    │
│  │  ONNX Model Files (encrypted filesystem)                   │    │
│  │  Secure Enclave (TPM: device cert + payment keys)          │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                           │                                          │
│  INFRASTRUCTURE LAYER                                                │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Azure IoT Edge Agent (module updates, telemetry)           │    │
│  │  Azure AD: Device Registration + RBAC (staff identities)   │    │
│  │  TLS 1.3: all network communication                        │    │
│  └─────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Transaction Engine — State Machine

```
                    ┌────────────┐
                    │   IDLE     │◄──────── Shift start
                    └─────┬──────┘
                          │ First item scan / manual entry
                          ▼
                    ┌────────────┐
                    │  SCANNING  │◄──── Scan barcode / manual SKU
                    └─────┬──────┘      / Remove item (void line)
                          │ "Payment" button pressed
                          ▼
                    ┌────────────┐
                    │  TOTALLING │  Tax calc, promo apply,
                    │            │  loyalty resolve, AI promo rank
                    └─────┬──────┘
                          │
                          ▼
                    ┌────────────┐
                    │  PAYMENT   │  Online: P2PE → Gateway
                    │  PENDING   │  Offline: P2PE → Token engine
                    └─────┬──────┘
                          │ Approved
                          ▼
                    ┌────────────┐
                    │ COMPLETING │  Receipt print, loyalty update,
                    │            │  event written to SQLite outbox
                    └─────┬──────┘
                          │
                          ▼
                    ┌────────────┐
                    │  COMPLETE  │  Sync agent picks up outbox event
                    └─────┬──────┘
                          │ Next customer
                          ▼
                    ┌────────────┐
                    │   IDLE     │
                    └────────────┘

  Exception paths:
  Any state → VOID (manager auth required for completed TX)
  PAYMENT PENDING → DECLINED → back to TOTALLING
  Any state → SUSPEND (held basket; resume with basket ID)
```

---

## 4. Offline Mode Design

### 4.1 Offline Detection
```
Background health-check thread: ping Store Edge API every 10 seconds
  └── 3 consecutive failures (30s) → switch to OFFLINE mode
  └── 1 success → attempt DEGRADED ONLINE → 3 successes → ONLINE
```

### 4.2 Data Available Offline

| Data | Source | Cache Strategy | Max Staleness |
|---|---|---|---|
| Product catalogue (SKU/barcode/name) | Store Edge → SQLite | Full copy, push-updated | 15 minutes |
| Pricing rules | Store Edge → SQLite | Versioned, delta push | 5 minutes |
| Promotion rules | Store Edge → SQLite | Versioned, delta push | 5 minutes |
| Tax rates | Store Edge → SQLite | Versioned, push on change | 1 day |
| Staff credentials | AAD → PBKDF2 hash SQLite | Hash-only (no PW plaintext) | 4 hours |
| Loyalty balance | Store Edge → SQLite | Last-known (delta on sync) | 5 minutes |
| Currency FX rates | Store Edge → SQLite | Last-known fallback | 15 minutes |
| AI fraud model | IoT Hub OTA → ONNX file | Versioned, background update | 24 hours |
| AI promo model | IoT Hub OTA → ONNX file | Versioned, background update | 24 hours |

### 4.3 Capabilities Degraded Offline

| Capability | Online | Offline |
|---|---|---|
| Product lookup | Store Edge → Cloud catalogue | SQLite cache (last synced) |
| Payment approval | Real-time gateway auth | Offline token (within ceiling) |
| Fraud scoring | Full neural ensemble | ONNX LightGBM (local, reduced features) |
| Personalised promos | Real-time ML recommendation | Segment-based cached rules |
| Loyalty redemption | Real-time balance check | Last-known balance (risk-managed) |
| NLP assistant | GPT-4o cloud | Phi-3 on store edge (if store edge available) |
| Receipt email | Cloud notification service | Queued; sent on reconnect |

---

## 5. Payment Handling Architecture

### 5.1 Online Payment Flow
```
Customer presents card/NFC/QR
    │
POS Payment SDK: P2PE encrypt (hardware security module in terminal)
    │ (PAN never enters POS application memory)
TLS 1.3 → Store Edge Payment Proxy → Azure APIM
    │
Azure Payment Service → Payment Gateway (Adyen/Stripe)
    │
Approved: auth code returned → transaction completed
Declined: reason code → cashier notified → alternative payment offered
```

### 5.2 Offline Payment Flow
```
Customer presents card/NFC/QR
    │
POS Payment SDK: P2PE encrypt → Offline Token Engine
    │
Ceiling check (HQ-signed JSON config in TPM):
  ├ TX amount ≤ per-transaction ceiling: PROCEED
  └ TX amount > ceiling: DECLINE (prompt alternative / manager override)
    │
Offline token generated:
  HMAC-SHA256(device_id + merchant_id + masked_PAN + amount + nonce + expiry)
    │
Token + encrypted payment record stored in SQLite (AES-256)
    │
On reconnect: tokens batched → sent to Payment Service → gateway settlement
Settlement must complete within 72 hours
```

### 5.3 Payment Method Support

| Method | Online | Offline | Notes |
|---|---|---|---|
| EMV Chip + PIN | ✅ | ✅ (token) | Primary card method |
| Contactless NFC | ✅ | ✅ (token, limit enforced) | Apple Pay, Google Pay, NFC card |
| QR Code | ✅ | ❌ (requires scan validation) | WeChat Pay, UPI, etc. |
| MSR (swipe) | ✅ | ❌ (disabled offline — fraud risk) | Legacy; blocked offline |
| Cash | ✅ | ✅ (no network needed) | Cash drawer integration |
| Gift Card | ✅ | ✅ (balance pre-loaded to SQLite) | Balance sync on reconnect |
| Split Payment | ✅ | ✅ (within combined ceiling) | Any combination of above |

---

## 6. AI Module Integration

### 6.1 Fraud Scoring at POS

```
Transaction ready for payment (basket locked)
    │
Feature extractor: amount, item_count, discount_pct, time_of_day,
                   velocity_1h, velocity_24h, device_id, card_BIN
    │
ONNX Runtime: load fraud_detection_v{N}.onnx (loaded at startup)
    │
Inference: < 50ms guaranteed (P99 on reference hardware)
    │
Score 0.0 – 1.0:
  0.0 – 0.40: Allow (normal flow)
  0.40 – 0.70: Step-up (manager PIN approval)
  0.70 – 1.00: Decline + silent alert to store manager
```

### 6.2 Promotion Ranking at POS

```
Basket finalised → eligible promotions resolved (rule engine)
    │
Potentially 5–20 eligible promotions for basket
    │
ONNX promo ranker: contextual features + customer segment
    │
Top 3 promotions selected (maximise: relevance × margin × urgency)
    │
Applied to basket + displayed on customer-facing screen
```

---

## 7. Self-Checkout Kiosk (Extended POS)

The self-checkout kiosk is a specialised POS instance running on a Linux touchscreen unit with an attached camera array and optional weight scale.

```
Item placed on scanner surface
    │
Barcode scan attempted first (primary, fastest)
    │ [Barcode not readable / obscured]
Camera array: YOLOv8 ONNX inference (store edge, served via local API)
    │
Item class + confidence score:
  ≥ 0.92: auto-add to basket
  < 0.92: prompt customer to re-present item / call attendant
    │
Weight verification (if scale present):
  Expected weight (from catalogue) vs. scale weight
  Mismatch > 5%: attendant intervention required
    │
Anti-theft: unscanned item in bagging area → freeze + attendant alert
```

---

## 8. POS Hardware Telemetry

All POS terminals emit the following telemetry to Azure IoT Hub (via Store Edge) every 60 seconds:

```json
{
  "device_id": "POS-STORE001-T01",
  "tenant_id": "franchisee_042",
  "timestamp": "2026-06-11T10:00:00Z",
  "metrics": {
    "cpu_pct": 23,
    "memory_mb_used": 1842,
    "disk_free_gb": 42.1,
    "transactions_last_1h": 87,
    "sync_queue_depth": 0,
    "last_sync_success_ts": "2026-06-11T09:59:48Z",
    "offline_since": null,
    "printer_status": "OK",
    "scanner_status": "OK",
    "card_reader_status": "OK",
    "network_latency_ms": 12,
    "onnx_fraud_model_version": "2.4.1",
    "onnx_promo_model_version": "1.8.0"
  }
}
```

This telemetry feeds the Predictive Maintenance AI model (UC6).

---

## 9. Security Controls at POS Tier

| Control | Implementation |
|---|---|
| Device Identity | X.509 certificate issued at provisioning; stored in TPM |
| Staff Authentication | Azure AD + local PIN (PBKDF2 hash); MFA on manager functions |
| Payment Data | P2PE — encrypted in hardware, never in application memory |
| Data at Rest | SQLite encrypted with SQLCipher (AES-256-CBC) |
| Network | TLS 1.3 with certificate pinning (Store Edge + IoT Hub) |
| AI Model Integrity | SHA-256 hash verified at startup; reject if tampered |
| Software Updates | Signed packages only; IoT Hub SAS token validation |
| Physical | POS tamper detection logged; alert on case open |

---

## 10. Related Documents

| Document | Reference |
|---|---|
| Transaction Engine LLD | `02_LLD/LLD-001_POS_Transaction_Engine.md` |
| Offline Sync Agent LLD | `02_LLD/LLD-002_Offline_Sync_Agent.md` |
| Payment Service LLD | `02_LLD/LLD-012_Payment_Service.md` |
| Fraud Detection LLD | `02_LLD/LLD-004_Fraud_Detection_Service.md` |
| Offline Architecture HLD | `01_HLD/HLD-010_Offline_Architecture.md` |
