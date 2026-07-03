# SKILL.md — Offline-First Architecture & Sync Mechanisms

**Skill Name:** offline-first-architecture

**Purpose:** Help AI agents understand and explain the offline-first design, sync recovery, conflict resolution, and data consistency across POS terminals, store edge, and cloud.

---

## When to Use This Skill

Use this skill when:
- **Offline capability questions** — "How long can a POS terminal work without connectivity?"
- **Sync mechanisms** — "How do transactions get from POS to cloud?"
- **Conflict resolution** — "What happens if two stores edit the same product offline, then reconnect?"
- **Recovery scenarios** — "How do we handle 3-day store outages? What data is lost?"
- **Event consistency** — "Are transactions guaranteed to sync in order?"
- **CRDT details** — "How does Conflict-free Replicated Data Types work in our system?"
- **Offline queue management** — "What happens if the sync queue grows too large?"

Do NOT use this skill for:
- General transaction processing (use [HLD-002](EnterpriseRetailAI-Docs/HLD-002_POS_Application.md) directly)
- Network protocols (use [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md))
- Code-level implementation

---

## Core Pattern: Offline-First Architecture

EnterpriseRetailAI is **offline-first**, not online-first with offline fallback.

**Key Principle:**
```
POS Terminal = Autonomous Unit
├─ Operates indefinitely without connectivity
├─ Logs all transactions to local append-only event log
├─ Queues events for sync when connection available
└─ Resolves conflicts with store edge on reconnect (CRDT)

Store Edge = Semi-Autonomous Unit
├─ Operates for weeks without cloud connectivity
├─ Batches POS events, applies local processing
├─ Queues for cloud sync when WAN available
└─ Uses CRDT to merge cloud changes on reconnect

Cloud = Centralized Source of Truth
├─ Receives event streams from stores
├─ Produces analytics, reporting, model training
├─ Syncs config updates back to stores
└─ Maintains complete transaction audit trail
```

**Design Rationale:** See [ADR-003_Event_Sourcing.md](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md) + [HLD-010_Offline_Architecture.md](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md)

---

## Three-Level Offline Resilience

### Level 1: POS Terminal Offline

**Scenario:** Internet down, store edge up

```
POS Terminal (Offline)
├─ Transaction Processing: ✅ Full capability
│  ├─ Scan items, apply promotions, process payment (offline queue)
│  └─ Print receipt
├─ Local Data: ✅ Available
│  ├─ Product catalog (cached)
│  ├─ Promotions (cached)
│  ├─ Inventory (cached, may be stale)
│  └─ Customer info (cached)
├─ ML Inference: ✅ Works (ONNX models on device)
│  ├─ Fraud scoring (real-time)
│  └─ Promo ranking (real-time)
├─ Event Log: ✅ Persists locally
│  └─ Append-only SQLite log (never lost)
├─ Sync Status: ⏳ Queued
│  └─ Events await store edge reconnection
└─ Duration: ⏱️ Indefinite (days, weeks if needed)

Store Edge (Online)
├─ Pulls events from POS batch every 5 minutes
├─ Queues for cloud sync
└─ Continues to serve HQ analytics
```

**Reference:** [HLD-010_Offline_Architecture.md](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-002_Offline_Sync_Agent.md](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md)

### Level 2: Store Edge Offline

**Scenario:** Store WAN down, cloud unreachable

```
Store Edge (Offline)
├─ POS Support: ✅ Full capability
│  ├─ Sync agent continues batch pulls from POS
│  ├─ Queues events locally (PostgreSQL queue tables)
│  └─ Serves local reporting
├─ Local Processing: ✅ Works
│  ├─ Inventory sync from POS
│  ├─ ML feature store updates
│  └─ Staff reporting (local only)
├─ Cloud Sync: ❌ Blocked
│  ├─ Events queue in PostgreSQL
│  ├─ Config updates not received
│  └─ New models not deployed
└─ Duration: ⏱️ 2-3 weeks (typical), much longer possible

POS Terminals (Online to Store Edge)
├─ Continue normal operation
├─ Sync to store edge every 5 minutes
└─ No awareness of cloud outage
```

**Reference:** [HLD-010_Offline_Architecture.md](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md), [LLD-003_Store_Edge_Orchestration.md](EnterpriseRetailAI-Docs/LLD-003_Store_Edge_Orchestration.md)

### Level 3: POS + Store Edge Offline

**Scenario:** Complete store network failure, no local data center

```
POS Terminal (Offline)
├─ Operation: ✅ Continues indefinitely
├─ Local Event Log: ✅ Persists (SQLite)
├─ ML Inference: ✅ Works (ONNX on-device)
└─ Sync: ❌ Cannot reach store edge

Store Edge (Offline)
├─ No WAN, no LAN connection
├─ Cannot help POS sync
└─ Waiting for restoration

Recovery: When store reconnects
├─ Restore LAN connection → POS syncs to store edge
├─ Restore WAN connection → Store syncs to cloud
└─ CRDT resolves any concurrent offline edits
```

**Timeline:** POS can operate indefinitely (days, weeks, months) in complete isolation

---

## Synchronization Mechanisms

### Step 1: POS → Store Edge Sync (5-minute batch)

**Trigger:** Every 5 minutes, or when network available, whichever comes first

**Process:**
```
POS Sync Agent (on terminal)
├─ 1. Query local event log (SELECT * FROM events WHERE synced = false)
├─ 2. Serialize to JSON (event_id, event_type, data, timestamp)
├─ 3. HTTP POST to store edge `/api/sync/events`
├─ 4. Wait for acknowledgment
├─ 5. Mark local events as synced = true
└─ 6. Repeat in 5 minutes

Store Edge Sync Agent (on-premises)
├─ 1. Receive events from POS
├─ 2. Apply CRDT merge (if conflicting)
├─ 3. Store in sync queue table (PostgreSQL)
├─ 4. Send ACK back to POS
├─ 5. Update local inventory/analytics
└─ 6. Queue for cloud sync
```

**Idempotency:** Events are idempotent; re-sync is safe

**Reference:** [LLD-002_Offline_Sync_Agent.md](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md)

### Step 2: Store Edge → Cloud Sync (continuous streaming)

**Trigger:** Continuous streaming to Azure Event Hubs

**Process:**
```
Store Edge Event Streaming (continuous)
├─ 1. Stream events to Azure Event Hubs (partition by store_id)
├─ 2. Guarantee ordering per store (events have vector clock)
├─ 3. Include metadata (tenant_id, store_id, timestamp, version)
├─ 4. Receive checkpointing ACK
├─ 5. Resume from last checkpoint if interrupted
└─ 6. Continue indefinitely (queue survives outages)

Azure Cloud Processing (serverless)
├─ 1. Event Hubs triggers Azure Functions
├─ 2. Functions enrich events (geo, customer validation)
├─ 3. Store in Azure SQL (append-only event table)
├─ 4. Trigger downstream processing (analytics, ML feature store)
└─ 5. Delete from queue (after durable storage)
```

**Exactly-once Delivery:** Events guaranteed once using vector clocks + idempotency

**Reference:** [ADR-003_Event_Sourcing.md](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md), [LLD-011_Event_Sync_CRDT_Engine.md](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md)

---

## Conflict Resolution: CRDT (Conflict-free Replicated Data Type)

### The Problem: Concurrent Offline Edits

**Scenario:** Store A and Store B both offline, editing the same product inventory

```
Time 0: Product "Widget" quantity = 100

Store A (offline):         Store B (offline):
├─ 10:00 AM: Sell 5        ├─ 10:05 AM: Sell 3
│  Widget qty = 95         │  Widget qty = 97
├─ 10:15 AM: Receive 20    ├─ 10:20 AM: Receive 2
│  Widget qty = 115        │  Widget qty = 99
└─ Event log:              └─ Event log:
   [Sell 5, Receive 20]       [Sell 3, Receive 2]

Time = 11:00 AM: Both stores reconnect

Question: What should qty be?
- Store A says: 115
- Store B says: 99
- Actual qty in cloud: 100

Answer: CRDT merges to 97 (100 - 5 - 3, ignoring receives as they require cloud sync)
```

**Solution: CRDT**

CRDT is a data structure that:
1. **Replicates state across multiple nodes** (POS, Store Edge, Cloud)
2. **Allows concurrent updates** without coordination
3. **Automatically merges conflicts** (no last-write-wins)
4. **Guarantees eventual consistency** (all replicas converge to same state)

### CRDT Types Used

| Data Type | Use Case | Merge Algorithm |
|---|---|---|
| **Counter (G-Counter)** | Inventory changes, transaction counts | Sum all increments (immutable) |
| **Register (LWW-Element-Set)** | Product names, prices | Last-write-wins with timestamp |
| **Map (CRDT Map)** | Inventory state | Per-key CRDT merge |
| **Set (ORSet)** | Inventory items, collections | Add-wins (remove must know operation) |

### Example: Inventory Merge with CRDT

```
Store A Events:                Store B Events:
├─ T1: Sell 5 (count -= 5)    ├─ T2: Sell 3 (count -= 3)
└─ T3: Add 20 (count += 20)   └─ T4: Add 2 (count += 2)

CRDT Merge Algorithm:
1. Extract all increment/decrement operations
2. Sum independently: -5 + 20 - 3 + 2 = 14
3. Final state: base (100) + net change (14) = 114

But: Receives require stock at source, so:
- Sell 5: ✅ Allowed (qty >= 5)
- Sell 3: ✅ Allowed (qty >= 3)
- Add 20 from Store A: ❌ Disallowed (no stock at cloud)
- Add 2 from Store B: ❌ Disallowed (no stock at cloud)

Final result: qty = 100 - 5 - 3 = 92 (conservative merge)
```

**Reference:** [ADR-006_CRDT_Conflict_Resolution.md](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md), [LLD-011_Event_Sync_CRDT_Engine.md](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md)

---

## Recovery Example: 3-Day Store Outage

**Scenario:** Store loses all connectivity (POS, Store Edge, WAN) for 3 days

**Timeline:**

```
Day 1 (8 AM): Outage begins
├─ POS terminals detect no store edge connection
├─ All POS terminals switch to autonomous mode
├─ Events logged locally, queued for sync
└─ No data loss (append-only log survives hard resets)

Day 1-3: Operation Continues
├─ POS terminals process transactions normally
├─ Each terminal has independent event log
├─ ML inference works (ONNX on-device)
├─ No sync to store edge or cloud
├─ Store edge sits idle (no cloud sync possible)
└─ Total transactions queued: ~5,000 (estimate)

Day 4 (8 AM): Connectivity Restored
├─ 1. Network reconnects (LAN between POS and Store Edge)
├─ 2. POS sync agent detects connection
├─ 3. All 5,000 events stream from POS to Store Edge (batch pulls, ~10 mins)
├─ 4. CRDT engine resolves any conflicts from concurrent edits
├─ 5. Store Edge now in sync with POS
├─ 6. WAN reconnects (Store Edge to Cloud)
├─ 7. All 5,000 events stream to cloud (~30 mins)
├─ 8. Cloud applies CRDT if any conflicts
├─ 9. Inventory, transactions, analytics all updated
└─ 10. Operations resume normal

Timeline Summary:
├─ 3 days: Zero data loss, POS operates autonomously
├─ 40 minutes: Full sync recovery once connectivity restored
└─ Result: Eventual consistency (all systems converge)
```

**Data Loss:** ZERO (all events logged locally)
**Consistency Time:** ~40 minutes to full convergence
**User Impact:** Minimal (no transactions lost, stale inventory for 3 days)

**Reference:** [HLD-010_Offline_Architecture.md](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md)

---

## Comparison: Offline vs. Online

| Aspect | Offline-First | Online-First |
|---|---|---|
| **POS Standalone?** | ✅ Yes, indefinitely | ❌ Fails without connection |
| **Data Loss Risk** | ❌ None (local log) | ✅ High (no local persistence) |
| **Conflict Resolution** | ✅ CRDT (automatic) | ❌ Last-write-wins or manual |
| **Recovery Time** | ✅ ~40 min for 3-day outage | ❌ System down for 3 days |
| **Complexity** | ❌ Higher (CRDT, versioning) | ✅ Lower |
| **Network Utilization** | ✅ Lower (batch, async) | ❌ Higher (real-time sync) |

---

## Offline Queue Management

### Queue Growth During Outages

```
Normal state: Queue ~10 events (5 sec lag)
8-hour outage: Queue ~6,000 events (8 * 12 txn/min)
3-day outage: Queue ~17,000 events (3 * 24 * 12 txn/min)
7-day outage: Queue ~40,000 events (feasible, ~10 MB)
14-day outage: Queue ~80,000 events (~20 MB, acceptable)
```

**Limits & Handling:**
- **Max queue size:** 100,000 events per store (~25 MB)
- **Max queue age:** 30 days (after 30 days, warn ops team)
- **Risk if exceeded:** OOM on POS terminal; logs rotated (oldest events deleted)
  - **Mitigation:** Never delete unsynced events; upgrade storage if approaching limit

**Reference:** [LLD-002_Offline_Sync_Agent.md](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md)

---

## Reference Map

| Question | Document |
|---|---|
| What is the offline-first design? | [HLD-010_Offline_Architecture.md](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md) |
| How does sync work? | [LLD-002_Offline_Sync_Agent.md](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md) |
| How is CRDT used? | [ADR-006_CRDT_Conflict_Resolution.md](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md) |
| CRDT implementation? | [LLD-011_Event_Sync_CRDT_Engine.md](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md) |
| Why event sourcing? | [ADR-003_Event_Sourcing.md](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md) |
| Transaction processing? | [LLD-001_POS_Transaction_Engine.md](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md) |
| Store edge orchestration? | [LLD-003_Store_Edge_Orchestration.md](EnterpriseRetailAI-Docs/LLD-003_Store_Edge_Orchestration.md) |

---

## Tips for Agents

1. **Explain autonomy first** — POS works indefinitely offline; this is the key design principle
2. **Show the three levels** — POS offline, Store offline, Cloud offline (all can happen)
3. **Use the timeline** — Walk through the 3-day outage scenario to show recovery
4. **Mention CRDT** — Explain conflict resolution is automatic, not manual or last-write-wins
5. **Cite event sourcing** — Explain how immutable events enable recovery
6. **Reference idempotency** — Mention events are safe to re-sync
7. **Show queue limits** — Explain queue growth is bounded (~80K events after 14 days)

---

## When You Don't Know the Answer

If a user asks about offline-first scenarios not covered here:
1. Check if the question belongs to general transaction design (use [LLD-001](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md))
2. If a scenario exists but is missing, note this as a gap
3. Point to the nearest analogous scenario (e.g., "POS offline works like Store Edge offline")
