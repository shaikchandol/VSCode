# LLD-011 — Event Sync & CRDT Engine
## EnterpriseRetailAI · Event Schema, CRDT Types, Merge Algorithm, Idempotency

---

| Document ID | LLD-011 | Version | 1.0 | Status | Approved | Date | June 2026 |

---

## 1. Purpose

This document defines the CRDT-based conflict-free event merge engine that reconciles events from multiple offline POS terminals and store edge nodes when connectivity is restored. It guarantees that concurrent, causally-independent writes from different devices always converge to a consistent state.

---

## 2. CRDT Types Used

| Data Entity | CRDT Type | Semantics |
|---|---|---|
| Inventory quantity | PN-Counter | Independent increment (sale) + decrement (receipt) |
| Loyalty points (earn) | G-Counter per customer | Monotonic accumulation, never lose |
| Loyalty points (burn) | PN-Counter | Tracked separately from earn |
| Transaction event | Immutable Add-only Set | Append-only; no merging needed |
| Shift record | LWW-Register | Last-write-wins by wall-clock + POS-ID tiebreak |
| Customer profile | LWW-Register | Last-write-wins; timestamp + device-clock vector |
| Price / Promo rule | LWW-Register | Admin action — last HQ push wins |
| Stock alert threshold | LWW-Register | Admin action wins |

---

## 3. Event Schema (CloudEvents v1.0 + Avro)

```json
{
  "specversion":          "1.0",
  "id":                   "uuid-v7",
  "type":                 "com.retailai.transaction.completed",
  "source":               "/store/store_001/pos/pos_042",
  "time":                 "2026-06-11T10:00:00.123Z",
  "datacontenttype":      "application/avro",
  "dataschema":           "https://schemas.retailai.com/transaction/v2.1.0",
  "retailai-tenantid":    "franchisee_042",
  "retailai-storeid":     "store_uuid",
  "retailai-posid":       "pos_uuid",
  "retailai-idempotencykey": "uuid-v4",
  "retailai-vectorclock": "{\"pos_042\":1042,\"pos_043\":887}",
  "retailai-wallclock":   "1749600000123",
  "data":                 "<Avro-binary>"
}
```

### Avro Schema: transaction.completed (v2.1.0)

```json
{
  "namespace":  "com.retailai.events",
  "type":       "record",
  "name":       "TransactionCompleted",
  "doc":        "Emitted when a POS transaction is successfully completed",
  "fields": [
    {"name": "transaction_id",     "type": "string"},
    {"name": "tenant_id",          "type": "string"},
    {"name": "store_id",           "type": "string"},
    {"name": "pos_id",             "type": "string"},
    {"name": "cashier_id",         "type": "string"},
    {"name": "shift_id",           "type": "string"},
    {"name": "idempotency_key",    "type": "string"},
    {"name": "opened_at",          "type": {"type":"long","logicalType":"timestamp-millis"}},
    {"name": "completed_at",       "type": {"type":"long","logicalType":"timestamp-millis"}},
    {"name": "currency",           "type": "string"},
    {"name": "subtotal_minor",     "type": "long"},
    {"name": "tax_total_minor",    "type": "long"},
    {"name": "discount_total_minor","type":"long"},
    {"name": "grand_total_minor",  "type": "long"},
    {"name": "payment_method",     "type": ["null","string"]},
    {"name": "is_offline_tx",      "type": "boolean"},
    {"name": "customer_id",        "type": ["null","string"]},
    {"name": "loyalty_id",         "type": ["null","string"]},
    {"name": "lines",              "type": {"type":"array","items": {
      "type": "record", "name": "TransactionLine",
      "fields": [
        {"name": "line_id",            "type": "string"},
        {"name": "sku_id",             "type": "string"},
        {"name": "product_name",       "type": "string"},
        {"name": "quantity",           "type": "int"},
        {"name": "unit_price_minor",   "type": "long"},
        {"name": "tax_amount_minor",   "type": "long"},
        {"name": "discount_minor",     "type": "long"},
        {"name": "line_total_minor",   "type": "long"}
      ]
    }}},
    {"name": "applied_promotions", "type": {"type":"array","items":"string"}},
    {"name": "vector_clock",       "type": "string"}
  ]
}
```

---

## 4. Vector Clock Implementation (Azure Stream Analytics)

```sql
-- Azure Stream Analytics query: CRDT merge for inventory updates
-- Input: Event Hubs 'inventory-updates' topic

WITH IncomingUpdates AS (
    SELECT
        TRY_CAST(GetMetadataPropertyValue(inventory, 'retailai-tenantid') AS NVARCHAR(MAX)) AS tenant_id,
        EventData.store_id,
        EventData.sku_id,
        EventData.quantity_delta,
        EventData.movement_type,
        EventData.idempotency_key,
        EventData.vector_clock,
        EventData.wall_clock_ms,
        EventProcessedUtcTime AS processed_at
    FROM inventory [inventory]
    TIMESTAMP BY EventProcessedUtcTime
),

-- Deduplication window: 24 hours by idempotency_key
Deduplicated AS (
    SELECT *
    FROM IncomingUpdates
    WHERE idempotency_key NOT IN (
        SELECT idempotency_key
        FROM IncomingUpdates
        TIMESTAMP BY processed_at
        WHERE DATEDIFF(hour, processed_at, EventProcessedUtcTime) < 24
    )
)

-- Output to SQL for canonical store
SELECT
    tenant_id,
    store_id,
    sku_id,
    SUM(quantity_delta) OVER (
        PARTITION BY tenant_id, store_id, sku_id
        LIMIT DURATION(minute, 5)
    ) AS net_quantity_delta,
    MAX(wall_clock_ms) AS last_update_ms,
    COLLECT() AS events_in_window
INTO canonical_inventory
FROM Deduplicated
GROUP BY tenant_id, store_id, sku_id,
         TumblingWindow(minute, 5);
```

---

## 5. CRDT Merge Algorithm (Python — cloud merge service)

```python
from dataclasses import dataclass, field
from typing import Optional
import json

@dataclass
class VectorClock:
    clock: dict[str, int] = field(default_factory=dict)

    def tick(self, node_id: str) -> int:
        self.clock[node_id] = self.clock.get(node_id, 0) + 1
        return self.clock[node_id]

    def merge(self, other: "VectorClock") -> "VectorClock":
        merged = {}
        all_keys = set(self.clock) | set(other.clock)
        for k in all_keys:
            merged[k] = max(self.clock.get(k, 0), other.clock.get(k, 0))
        return VectorClock(merged)

    def happens_before(self, other: "VectorClock") -> bool:
        return (
            all(self.clock.get(k, 0) <= other.clock.get(k, 0) for k in self.clock)
            and any(self.clock.get(k, 0) < other.clock.get(k, 0) for k in self.clock)
        )

    def is_concurrent(self, other: "VectorClock") -> bool:
        return not self.happens_before(other) and not other.happens_before(self)


class PNCounter:
    """
    PN-Counter CRDT for inventory quantities.
    Positive increments (receipts) and negative (sales) tracked separately.
    """
    def __init__(self):
        self.P: dict[str, int] = {}   # increments per node
        self.N: dict[str, int] = {}   # decrements per node

    def increment(self, node_id: str, amount: int = 1):
        self.P[node_id] = self.P.get(node_id, 0) + amount

    def decrement(self, node_id: str, amount: int = 1):
        self.N[node_id] = self.N.get(node_id, 0) + amount

    @property
    def value(self) -> int:
        return sum(self.P.values()) - sum(self.N.values())

    def merge(self, other: "PNCounter") -> "PNCounter":
        result = PNCounter()
        all_nodes = set(self.P) | set(other.P)
        for n in all_nodes:
            result.P[n] = max(self.P.get(n, 0), other.P.get(n, 0))
        all_nodes = set(self.N) | set(other.N)
        for n in all_nodes:
            result.N[n] = max(self.N.get(n, 0), other.N.get(n, 0))
        return result


class LWWRegister:
    """
    Last-Write-Wins Register for customer profiles, shift records.
    Tiebreak: higher node_id string (deterministic, lexicographic).
    """
    def __init__(self, value=None, timestamp: int = 0, node_id: str = ""):
        self.value     = value
        self.timestamp = timestamp
        self.node_id   = node_id

    def write(self, value, timestamp: int, node_id: str) -> "LWWRegister":
        if (timestamp > self.timestamp or
            (timestamp == self.timestamp and node_id > self.node_id)):
            return LWWRegister(value, timestamp, node_id)
        return self

    def merge(self, other: "LWWRegister") -> "LWWRegister":
        return self.write(other.value, other.timestamp, other.node_id)


class InventoryCRDTMerger:
    """
    Merges inventory update events from multiple POS and store edge nodes.
    """
    def merge_inventory_updates(
        self,
        store_id: str,
        sku_id: str,
        events: list[dict],
    ) -> int:
        """
        Given all inventory movement events for a SKU,
        compute the correct net quantity using PN-Counter merge.
        """
        counter = PNCounter()

        for event in events:
            node_id = event["pos_id"] or event["store_id"]
            delta   = event["quantity_delta"]
            if delta > 0:
                counter.increment(node_id, delta)
            else:
                counter.decrement(node_id, abs(delta))

        return counter.value

    def detect_conflicts(
        self,
        events: list[dict],
    ) -> list[tuple[dict, dict]]:
        """
        Find concurrent events (neither causally precedes the other).
        Returns list of (event_a, event_b) conflict pairs.
        """
        conflicts = []
        for i in range(len(events)):
            for j in range(i+1, len(events)):
                vc_a = VectorClock(json.loads(events[i]["vector_clock"]))
                vc_b = VectorClock(json.loads(events[j]["vector_clock"]))
                if vc_a.is_concurrent(vc_b):
                    conflicts.append((events[i], events[j]))
        return conflicts
```

---

## 6. Deduplication at Each Layer

```
Layer 1: POS SQLite outbox
  - UNIQUE constraint on idempotency_key
  - Same event never written twice (atomic DB transaction)

Layer 2: Store Edge Kafka
  - Kafka producer: enable.idempotence = true
  - Consumer dedup: idempotency_key tracked in Redis (TTL: 7 days)

Layer 3: Azure Event Hubs
  - Partition key: idempotency_key (ensures ordering per event)

Layer 4: Azure Stream Analytics
  - 24-hour deduplication window on idempotency_key
  - Tumbling window aggregation with COUNT(DISTINCT idempotency_key)

Layer 5: Azure SQL (canonical store)
  - UNIQUE constraint on idempotency_key column
  - ON CONFLICT DO NOTHING — safe to replay
```

---

## 7. Conflict Resolution Rules Summary

```python
CONFLICT_RULES = {
    # Entity              CRDT Type         Resolution
    "inventory":          ("pn_counter",    "merge_all_nodes"),
    "loyalty_earn":       ("g_counter",     "merge_all_nodes"),
    "loyalty_burn":       ("pn_counter",    "merge_all_nodes"),
    "transaction":        ("add_only_set",  "append_no_overwrite"),
    "shift_record":       ("lww_register",  "last_write_wins_by_wallclock"),
    "customer_profile":   ("lww_register",  "last_write_wins_by_wallclock"),
    "price_rule":         ("lww_register",  "last_hq_push_wins"),
    "promotion_rule":     ("lww_register",  "last_hq_push_wins"),
    "offline_payment":    ("add_only_set",  "append_pending_settlement"),
    "stock_alert":        ("lww_register",  "last_admin_action_wins"),
}
```

---

## 8. Reconciliation Report

After every sync recovery, a reconciliation report is auto-generated:

```json
{
  "report_id":          "uuid",
  "tenant_id":          "franchisee_042",
  "store_id":           "store_001",
  "offline_from":       "2026-06-11T08:00:00Z",
  "online_at":          "2026-06-11T11:23:45Z",
  "offline_duration_min": 203,
  "events_replayed":    1847,
  "events_deduplicated": 12,
  "conflicts_resolved": 3,
  "conflict_details": [
    {
      "entity":      "inventory",
      "sku_id":      "sku_001",
      "resolution":  "pn_counter_merge",
      "delta_applied": -5
    }
  ],
  "offline_transactions": 312,
  "offline_payment_tokens_settled": 47,
  "loyalty_delta_synced": 289,
  "summary": "Sync completed successfully. 3 inventory conflicts auto-resolved.",
  "generated_at": "2026-06-11T11:24:10Z"
}
```

---

## 9. Related Documents

- LLD-002: Offline Sync Agent
- HLD-010: Offline Architecture
- HLD-006: Data Architecture
- LLD-013: Data Schema Design
