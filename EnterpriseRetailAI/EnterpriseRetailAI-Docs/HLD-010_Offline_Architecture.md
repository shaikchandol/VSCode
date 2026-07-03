# HLD-010 — Offline Architecture
## EnterpriseRetailAI · POS Offline, Store Offline, Sync Recovery

| Document ID | HLD-010 | Version | 1.0 | Status | Approved | Date | June 2026 |

---

## 1. Offline Design Philosophy

Connectivity is an enhancement, not a dependency. Every POS terminal and store
edge server must sustain full trading operations independently, for an unbounded
duration, with guaranteed zero data loss on reconnection.

---

## 2. Offline Levels

```
LEVEL 0 — FULLY ONLINE
  POS ──(LAN)──► Store Edge ──(WAN)──► Azure Cloud
  All AI capabilities | Real-time sync | Live fraud scoring

LEVEL 1 — CLOUD DISCONNECTED (Store Edge intact)
  POS ──(LAN)──► Store Edge ──(WAN DEAD)──✗── Azure Cloud
  │
  ├ All POS transactions process via Store Edge (K3s services)
  ├ IoT Edge AI modules run locally (fraud, CV, NLP Phi-3)
  ├ Events queue in local Kafka (unbounded retention)
  ├ Offline payments tokenised by Store Edge token engine
  └ Recovery: WAN restored → Kafka consumer replays to Event Hubs

LEVEL 2 — STORE EDGE FAILURE (POS standalone)
  POS ──(LAN DEAD / Store Edge DOWN)──✗── Store Edge
  │
  ├ POS falls back to local SQLite (all cached data)
  ├ ONNX models serve AI locally on POS device
  ├ Offline payments tokenised by POS token engine (within ceiling)
  ├ Events stored in POS SQLite outbox
  └ Recovery: Store Edge restored → POS syncs to Store Edge → cloud

LEVEL 3 — TOTAL ISOLATION
  POS operates entirely standalone
  72-hour autonomous trading guaranteed by design
  Manual reconciliation guide available (PDF on POS)
```

---

## 3. POS Offline Data Architecture

```
SQLite (primary local store — SQLCipher AES-256):
  transactions          (append-only event log)
  transaction_lines     (line items per transaction)
  product_cache         (full catalogue, compressed)
  price_rules           (versioned, delta-synced)
  promotion_rules       (versioned, delta-synced)
  tax_rates             (per jurisdiction)
  staff_credentials     (PBKDF2 hashed — no plaintext)
  loyalty_delta         (offline accruals pending sync)
  offline_payment_tokens (AES-256 encrypted, 72h expiry)
  event_outbox          (pending sync events)
  sync_state            (vector clock per peer)

ONNX Model Files (encrypted at rest):
  fraud_detection_v{N}.onnx    (~15 MB — LightGBM quantised)
  promotion_ranker_v{N}.onnx   (~8 MB — gradient boost)

TPM Secure Enclave:
  Device X.509 certificate
  Payment tokenisation HMAC key
  Offline payment ceiling config (HQ-signed, tamper-proof)
```

---

## 4. Offline Payment Token Engine

```
Token structure (HMAC-SHA256 signed):
{
  "token_id":    "uuid-v4",
  "device_id":   "POS-STORE001-T01",
  "merchant_id": "franchisee_042_store_001",
  "masked_pan":  "4111 **** **** 1111",
  "card_hash":   "SHA256(PAN + nonce)",   // never store PAN
  "amount":      12345,                   // in minor currency units
  "currency":    "GBP",
  "timestamp":   "ISO8601",
  "expiry":      "timestamp + 72h",
  "nonce":       "crypto_random_16_bytes",
  "hmac":        "HMAC-SHA256(payload, device_key)"
}

Ceiling enforcement (HQ-signed JSON in TPM):
{
  "per_transaction_limit_gbp": 150,
  "per_shift_offline_limit_gbp": 2000,
  "allowed_card_types": ["emv_chip", "contactless_nfc"],
  "blocked_card_types": ["msr_swipe"],
  "valid_until": "2026-12-31",
  "hq_signature": "RSA-PSS(payload, hq_private_key)"
}

On reconnection: tokens batch-forwarded to Payment Service →
gateway settlement must complete within 72 hours.
```

---

## 5. CRDT-Based Conflict Resolution

```
Conflict Type              Resolution Strategy
─────────────────────────────────────────────────────
Inventory count            G-Counter (monotonic increment only)
                           Last-write-wins for adjustments (vector clock)
Transaction (completed)    Immutable — never overwritten
Loyalty points (accrue)    G-Counter per customer (additive CRDT)
Loyalty points (redeem)    Pairwise max (PN-Counter)
Price at time of sale      Captured at POS — immutable
Promotion applied          Captured at POS — immutable, audit-logged
Refund offline             Held PENDING until online verification
Customer profile update    Last-write-wins (timestamp + device clock)
Stock alert threshold       Last-write-wins (admin action)
```

---

## 6. Sync Recovery Sequence

```
T+00:00  Connectivity restored (any WAN link)
T+00:05  Store Sync Manager detects IoT Hub TCP connectivity
T+00:10  Sync Manager reads Kafka consumer group lag
         (total backlog events to replay)
T+00:15  Sync Manager begins publishing backlog:
         Rate: 10,000 events/minute (throttled)
         Compression: zstd (~10:1 ratio)
         Encryption: AES-256-GCM (tenant key)
         Protocol: AMQP 1.0 to Azure Event Hubs
T+??:??  Azure Stream Analytics: dedup + CRDT merge
         Canonical SQL schema updated
T+??:??  Sync Manager receives ACK for all events
         Kafka topic offsets committed
         Sync state updated (vector clocks reset)
T+??:??  Store transitions to ONLINE mode
         POS terminals notified (LAN broadcast)
         Reconciliation report auto-generated (PDF)
         Store Manager notified via app push notification
```

---

## 7. Offline AI Capabilities

| Capability | Online | Offline (Store Edge) | Offline (POS Only) |
|---|---|---|---|
| Fraud scoring | Full 35-feature neural ensemble | LightGBM ONNX (25 features) | LightGBM ONNX (18 features) |
| Promo ranking | Real-time collaborative filter | ONNX gradient boost (segment-based) | ONNX static rules |
| NLP assistant | GPT-4o (cloud) | Phi-3 Mini (edge SLM) | Not available |
| CV self-checkout | YOLOv8 full (store edge) | YOLOv8n ONNX (store edge) | Not available |
| Demand forecast | Azure ML TFT (daily) | TFT-lite (24h cached forecast) | 24h cached forecast |
| Predictive maint. | Live IoT Hub streaming | Local isolation forest | Local threshold alerts |

---

## 8. Related Documents

| Document | Reference |
|---|---|
| Offline Sync Agent LLD | `02_LLD/LLD-002_Offline_Sync_Agent.md` |
| Event Sync CRDT LLD | `02_LLD/LLD-011_Event_Sync_CRDT_Engine.md` |
| Payment Service LLD | `02_LLD/LLD-012_Payment_Service.md` |
| POS Application HLD | `01_HLD/HLD-002_POS_Application.md` |
| Store Edge HLD | `01_HLD/HLD-003_Store_Edge_Platform.md` |
