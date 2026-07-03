# SKILL.md — Performance & Scaling Guidance

**Skill Name:** performance-scaling

**Purpose:** Help AI agents and contributors understand performance considerations, capacity planning, and scaling patterns for the EnterpriseRetailAI platform.

---

## When to Use This Skill

Use this skill when:
- **High throughput questions** — "How does the platform scale for peak checkout traffic?"
- **Performance bottlenecks** — "What are the key latency-sensitive paths in POS sync?"
- **Capacity planning** — "How many store edge nodes are needed per location?"
- **Scaling architecture** — "What are the scale limits for the event sourcing pipeline?"
- **Monitoring and observability** — "What metrics should be tracked for system health?"

Do NOT use this skill for:
- Low-level SQL tuning (use `data-architecture` instead)
- Specific programming language performance hacks
- Detailed infrastructure provisioning commands

---

## Core Concepts

### 1. Performance Domains

- **POS Terminal**
  - Real-time response for checkout, payment, and local AI inference
  - Local SQLite event log optimized for append-only writes
  - Offline queue and sync back pressure control

- **Store Edge**
  - Batch sync processing and local feature store
  - K3s pod scaling for API, sync, and ML workloads
  - Use local caching to reduce call volume to cloud services

- **Cloud**
  - Azure AKS and Event Hubs for high-throughput event ingestion
  - Model training and analytics separated from real-time path
  - Global multi-region topology for data residency and resilience

### 2. Scaling Patterns

- **Horizontal scaling** of store edge services via K3s
- **Partitioning and sharding** for tenant schemas and transaction history
- **Batch processing** to offload heavy work from synchronous flows
- **Edge-first inference** to keep latency low on POS terminals

### 3. Performance Validation

- Monitor **latency** for checkout, sync, and fraud scoring
- Track **throughput** for event ingestion and cloud sync
- Validate **queue depth** at POS and Store Edge
- Audit **failover behavior** when offline or under load

---

## References
- `EnterpriseRetailAI-Docs/HLD-003_Store_Edge_Platform.md`
- `EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md`
- `EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md`
- `EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md`
- `EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md`
