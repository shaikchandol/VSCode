# ADR-006 — CRDT-based Offline Conflict Resolution
## EnterpriseRetailAI · Architecture Decision Record

| ID | ADR-006 | Status | Approved |

---

## Context

When a store is offline for hours (or days), multiple POS terminals independently update inventory, loyalty balances, and other shared state. On reconnection, the platform must merge these divergent states without manual intervention and without data loss.

Three strategies were evaluated: **CRDT**, **Last-Write-Wins (LWW)**, and **Manual Merge**.

---

## Decision

**CRDTs (Conflict-free Replicated Data Types)** are adopted as the primary merge strategy.

Specific CRDT types per entity:
- Inventory quantity: **PN-Counter** (monotonic increment + decrement per node)
- Loyalty earn points: **G-Counter** per customer (monotonically increasing, never lost)
- Transaction log: **Add-only set** (append-only, immutable — no conflict possible)
- Profile/config updates: **LWW-Register** with vector clock tiebreak

---

## Consequences

**Positive:**
- Mathematically guaranteed convergence — no human intervention needed
- Zero data loss: every POS terminal's events contribute to final state
- Deterministic output: same events always produce same result regardless of order
- Scales to 100+ POS terminals per store offline simultaneously

**Negative:**
- PN-Counter can show inventory > physical stock if returns processed offline
  → Mitigation: physical stock count reconciliation at shift close
- G-Counter loyalty points are irrevocable once merged
  → Mitigation: fraud threshold check on unusually large offline loyalty accrual
- Implementation complexity vs. LWW
  → Mitigation: encapsulated in Sync Manager (Rust) — one implementation, all tenants

**Not Using:** Last-Write-Wins for financial data — unacceptable to silently drop a valid transaction because a later timestamp arrived first.

