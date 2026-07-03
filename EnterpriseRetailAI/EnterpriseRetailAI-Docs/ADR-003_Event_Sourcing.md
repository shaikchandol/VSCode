# ADR-003 — Event Sourcing for Transaction State
## EnterpriseRetailAI · Architecture Decision Record

| ID | ADR-003 | Status | Approved |

---

## Context

POS transactions are financial records. The platform must:
- Never lose a transaction, even during connectivity outage
- Reproduce exact state at any point in time (audit, dispute)
- Merge concurrent events from multiple offline POS terminals
- Feed AI training pipelines with immutable historical data

Two patterns were evaluated: **Event Sourcing** and **CRUD with snapshots**.

---

## Decision

**Event Sourcing** is adopted for all transaction state changes.

Every state transition is recorded as an immutable event:
- `transaction.line.added`, `transaction.voided`, `payment.processed`, etc.
- Events stored in: POS SQLite → Store Edge Kafka → Azure Event Hubs → ADLS Gen2
- Current state is a projection (read model) from event log
- Idempotency keys prevent duplicate processing across network retries

---

## Consequences

**Positive:**
- Zero data loss: events buffered at every tier (SQLite → Kafka → Event Hubs)
- Time-travel queries for dispute resolution (replay events to any point)
- Natural audit trail for PCI-DSS Req 10 and financial reconciliation
- CRDT conflict resolution is natural with an event log (merge, not overwrite)
- AI training pipelines consume immutable historical event stream

**Negative:**
- Read queries require projection layer (CQRS pattern adds complexity)
- Storage grows unboundedly — mitigated by tiered lifecycle policy
- Eventual consistency means dashboards may lag by seconds

**Mitigations:**
- Read models maintained as materialised views in Azure SQL
- ADLS Gen2 lifecycle policy: Hot→Cool→Archive→Delete over 7 years
- Azure Stream Analytics maintains real-time read projections with < 60s lag

