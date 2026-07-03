# LLD-002 — Offline Sync Agent
## EnterpriseRetailAI · Detailed Design: Event Outbox, Sync Protocol, Vector Clocks

---

| Document ID | LLD-002 | Type | Low-Level Design | Version | 1.0 | Status | Approved |

---

## 1. Purpose

This document defines the low-level design of the Offline Sync Agent — the Rust-based background process running on every POS terminal responsible for reliably forwarding event outbox entries to the Store Edge server, and from there to Azure Event Hubs. It guarantees at-least-once delivery with exactly-once processing via idempotency keys.

---

## 2. Sync Agent Architecture (Rust)

```
pos-sync-agent (Rust, Tokio async)
├── outbox_reader.rs       // Polls SQLite event_outbox
├── transport.rs           // HTTPS client to Store Edge
├── compressor.rs          // zstd compression
├── encryptor.rs           // AES-256-GCM with tenant key
├── retry_policy.rs        // Exponential backoff with jitter
├── vector_clock.rs        // Per-peer vector clock tracking
├── ack_tracker.rs         // Event ACK state management
├── config.rs              // Runtime configuration
└── metrics.rs             // Prometheus metrics emission
```

---

## 3. Outbox Relay Loop

```rust
// Main relay loop — runs every 2 seconds (configurable)
pub async fn run_relay_loop(
    config: &SyncConfig,
    db: Arc<SqlitePool>,
    store_edge_client: Arc<StoreEdgeClient>,
    metrics: Arc<SyncMetrics>,
) -> Result<()> {
    let mut interval = tokio::time::interval(
        Duration::from_millis(config.relay_interval_ms)
    );

    loop {
        interval.tick().await;

        // 1. Read pending batch from outbox
        let pending = fetch_pending_events(&db, config.batch_size).await?;
        if pending.is_empty() { continue; }

        metrics.outbox_queue_depth.set(pending.len() as f64);

        // 2. Compress and encrypt batch
        let payload = prepare_payload(&pending, &config.encryption_key)?;

        // 3. Attempt delivery to Store Edge
        match store_edge_client.send_events(&payload).await {
            Ok(ack) => {
                // 4. Mark acknowledged events as dispatched
                mark_dispatched(&db, &ack.acknowledged_ids).await?;
                metrics.events_dispatched.inc_by(ack.acknowledged_ids.len() as f64);
            },
            Err(e) => {
                log::warn!("Store Edge unreachable: {e} — events retained in outbox");
                metrics.delivery_failures.inc();
                // Events NOT removed from outbox — will retry next cycle
            }
        }
    }
}
```

---

## 4. Vector Clock Implementation

```rust
/// Per-POS vector clock for CRDT merge ordering.
/// Clock is a map: peer_id → logical_timestamp
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VectorClock {
    clock: HashMap<String, u64>,
}

impl VectorClock {
    pub fn new(local_id: &str) -> Self {
        let mut clock = HashMap::new();
        clock.insert(local_id.to_string(), 0);
        Self { clock }
    }

    /// Increment local timestamp before sending an event
    pub fn tick(&mut self, local_id: &str) -> u64 {
        let ts = self.clock.entry(local_id.to_string()).or_insert(0);
        *ts += 1;
        *ts
    }

    /// Merge on receiving a remote clock (take max per entry)
    pub fn merge(&mut self, remote: &VectorClock) {
        for (peer, &remote_ts) in &remote.clock {
            let local_ts = self.clock.entry(peer.clone()).or_insert(0);
            *local_ts = (*local_ts).max(remote_ts);
        }
    }

    /// Compare: is self concurrent with other? (neither dominates)
    pub fn is_concurrent_with(&self, other: &VectorClock) -> bool {
        let self_gt  = self.clock.iter().any(|(k, &v)| v > *other.clock.get(k).unwrap_or(&0));
        let other_gt = other.clock.iter().any(|(k, &v)| v > *self.clock.get(k).unwrap_or(&0));
        self_gt && other_gt
    }
}
```

---

## 5. Idempotency Design

Every event carries an `idempotency_key` (UUID v4, generated when the
transaction is first opened). This key is:

1. **Written atomically** with the transaction commit in SQLite (same DB txn)
2. **Sent in the HTTP header** `Idempotency-Key` to Store Edge
3. **Tracked in Store Edge Kafka** — duplicate key → drop silently
4. **Forwarded to Azure Event Hubs** — Stream Analytics deduplication window: 24h

```rust
pub struct OutboxEntry {
    pub id:              String,     // outbox row PK
    pub idempotency_key: String,     // UUID v4 — globally unique per event
    pub event_type:      String,
    pub payload:         Vec<u8>,    // Avro-encoded event
    pub vector_clock:    String,     // JSON-serialised VectorClock
    pub created_at:      String,     // ISO8601 UTC
    pub dispatched_at:   Option<String>,
    pub retry_count:     u32,
}
```

---

## 6. Compression & Encryption Pipeline

```rust
pub fn prepare_payload(
    events: &[OutboxEntry],
    key: &EncryptionKey,
) -> Result<EncryptedPayload> {
    // Step 1: Serialise to newline-delimited JSON
    let ndjson: String = events
        .iter()
        .map(|e| serde_json::to_string(e))
        .collect::<Result<Vec<_>, _>>()?
        .join("\n");

    // Step 2: zstd compress (level 3 — balances speed vs. ratio)
    let compressed = zstd::encode_all(ndjson.as_bytes(), 3)?;

    // Step 3: AES-256-GCM encrypt
    let nonce = Nonce::from_slice(&rand::thread_rng().gen::<[u8; 12]>());
    let cipher = Aes256Gcm::new(&key.bytes);
    let ciphertext = cipher.encrypt(nonce, compressed.as_ref())
        .map_err(|e| anyhow!("Encryption failed: {e}"))?;

    Ok(EncryptedPayload {
        nonce:      nonce.to_vec(),
        ciphertext,
        event_count: events.len() as u32,
        batch_id:   Uuid::new_v4().to_string(),
    })
}
```

---

## 7. Retry Policy

```rust
pub struct RetryPolicy {
    pub max_attempts:   u32,    // default: 10
    pub base_delay_ms:  u64,    // default: 500ms
    pub max_delay_ms:   u64,    // cap: 30 seconds
    pub jitter_factor:  f64,    // 0.2 = ±20% jitter to avoid thundering herd
}

impl RetryPolicy {
    pub fn delay_for_attempt(&self, attempt: u32) -> Duration {
        let base = self.base_delay_ms * 2u64.pow(attempt.min(10));
        let capped = base.min(self.max_delay_ms);
        let jitter = (capped as f64 * self.jitter_factor * rand::random::<f64>()) as u64;
        Duration::from_millis(capped + jitter)
    }
}
```

---

## 8. SQLite Schema (event_outbox)

```sql
CREATE TABLE IF NOT EXISTS event_outbox (
    id               TEXT    NOT NULL PRIMARY KEY,
    idempotency_key  TEXT    NOT NULL UNIQUE,
    event_type       TEXT    NOT NULL,
    payload          BLOB    NOT NULL,    -- Avro-encoded, encrypted at rest
    vector_clock     TEXT    NOT NULL,    -- JSON
    created_at       TEXT    NOT NULL,    -- ISO8601
    dispatched_at    TEXT    NULL,        -- NULL = pending
    retry_count      INTEGER NOT NULL DEFAULT 0,
    last_error       TEXT    NULL
);

CREATE INDEX IF NOT EXISTS idx_outbox_pending
    ON event_outbox(dispatched_at, created_at)
    WHERE dispatched_at IS NULL;

-- Cleanup: purge dispatched events older than 7 days
-- (run nightly in maintenance window)
CREATE INDEX IF NOT EXISTS idx_outbox_cleanup
    ON event_outbox(dispatched_at)
    WHERE dispatched_at IS NOT NULL;
```

---

## 9. Store Edge Handshake Protocol

```
POS Sync Agent → Store Edge Sync Manager

POST /api/v1/sync/events
Headers:
  Authorization: Bearer {device_jwt}
  X-Device-ID: POS-STORE001-T01
  X-Tenant-ID: franchisee_042
  X-Batch-ID: {uuid}
  X-Event-Count: 47
  X-Vector-Clock: {"POS-T01":1042,"POS-T02":887}
  Content-Type: application/octet-stream
  Content-Encoding: zstd
Body: AES-256-GCM encrypted, zstd-compressed NDJSON event batch

Response 200 OK:
{
  "acknowledged_ids": ["id1", "id2", ...],
  "store_vector_clock": {"POS-T01":1042,"POS-T02":887,"STORE-EDGE":15023},
  "backpressure_wait_ms": 0   // > 0 means store edge is under load
}

Response 429 (backpressure):
{
  "retry_after_ms": 5000
}

Response 401: device cert or JWT invalid → re-enroll device
```

---

## 10. Connectivity Detection

```rust
pub struct ConnectivityMonitor {
    store_edge_url: Url,
    check_interval: Duration,          // default: 10 seconds
    offline_threshold: u32,            // consecutive failures before OFFLINE: 3
    online_threshold:  u32,            // consecutive successes before ONLINE: 1
    consecutive_failures: AtomicU32,
    consecutive_successes: AtomicU32,
    pub state: Arc<RwLock<ConnectivityState>>,
}

pub enum ConnectivityState {
    Online,
    DegradedOnline,   // single failure — buffering
    Offline,          // 3+ consecutive failures
    SyncRecovery,     // reconnected, replaying backlog
}
```

---

## 11. Metrics Emitted

| Metric Name | Type | Labels | Description |
|---|---|---|---|
| `sync.outbox.queue_depth` | Gauge | `pos_id` | Pending events in outbox |
| `sync.events.dispatched_total` | Counter | `pos_id`, `event_type` | Successfully dispatched |
| `sync.delivery.failures_total` | Counter | `pos_id`, `error_type` | Failed delivery attempts |
| `sync.batch.size` | Histogram | `pos_id` | Events per batch |
| `sync.batch.compression_ratio` | Gauge | `pos_id` | zstd compression ratio |
| `sync.retry.attempts` | Histogram | `pos_id` | Retries before success |
| `sync.connectivity.state` | Gauge | `pos_id`, `state` | 0=offline, 1=online |
| `sync.backlog.replay_rate` | Gauge | `pos_id` | Events/min during recovery |

---

## 12. Related Documents

| Document | Reference |
|---|---|
| Event Sync CRDT Engine LLD | `02_LLD/LLD-011_Event_Sync_CRDT_Engine.md` |
| Offline Architecture HLD | `01_HLD/HLD-010_Offline_Architecture.md` |
| Store Edge Platform HLD | `01_HLD/HLD-003_Store_Edge_Platform.md` |
| POS Transaction Engine LLD | `02_LLD/LLD-001_POS_Transaction_Engine.md` |
