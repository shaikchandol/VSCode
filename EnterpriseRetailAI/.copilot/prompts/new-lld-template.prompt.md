---
kind: prompt
name: new-lld-template
description: Template for creating new Low-Level Designs (LLDs) covering component, service, or detailed implementation architecture
applyTo:
  - "**/*LLD*.md"
  - "EnterpriseRetailAI-Docs/LLD-*.md"
---

# Low-Level Design (LLD) Template

Use this template when documenting component, service, or implementation-level architecture.

## Before You Start

1. **Identify the component** — What service or component does this LLD detail?
2. **Map to HLD** — Which HLD does this implement? (e.g., LLD-001 implements HLD-002)
3. **Check existing docs** — Is this already documented? (avoid duplication)
4. **Plan API/Schema** — What APIs does this expose? What data does it access?

## LLD Template

```markdown
# LLD-XXX — [Component/Service Name]

| Attribute | Value |
|---|---|
| Document ID | LLD-XXX |
| Type | Low-Level Design |
| Version | 1.0 |
| Status | Approved |
| Author | Enterprise Architecture Office |
| Date | [Month Year] |

## 1. Purpose

[One paragraph: What component/service does this LLD detail? What are its responsibilities?]

Example: "This document describes the Offline Sync Agent, responsible for queuing transaction events from POS terminals to the store edge, with conflict resolution via CRDT."

## 2. Architecture Overview

[Detailed architecture diagram showing this component's structure.]

### Component Diagram
```
┌────────────────────────────────┐
│  [This Component/Service]      │
│                                │
│  ┌──────────────────────────┐  │
│  │  Subcomponent 1          │  │
│  └──────────────────────────┘  │
│                                │
│  ┌──────────────────────────┐  │
│  │  Subcomponent 2          │  │
│  └──────────────────────────┘  │
│                                │
└────────────────────────────────┘
```

### Data Flow Diagram
[Show how data flows through this component]

## 3. Detailed Design

### 3.1 Core Responsibilities
- [Responsibility 1: detailed explanation]
- [Responsibility 2: detailed explanation]
- [Responsibility 3: detailed explanation]

### 3.2 Algorithms & State Machines

[If applicable, describe key algorithms or state machines.]

#### Example: Transaction State Machine
```
[Pending] --validate--> [Authorized] --complete--> [Settled]
   ^                          |                         |
   |                    --void--> [Voided]              |
   |                                                    |
   +---------------------- --return--> [Returned] -----+
```

### 3.3 Internal Architecture

[Describe modules, classes, or internal structure.]

Example:
- **Module A:** [Responsibility]
- **Module B:** [Responsibility]
- **Module C:** [Responsibility]

### 3.4 Configuration & Tuning

[What parameters can be configured? What are recommended values?]

Example:
```yaml
sync_interval_seconds: 300  # Batch sync every 5 minutes
max_queue_size: 100000      # Max events in offline queue
retry_backoff_seconds: 2    # Exponential backoff on failure
```

## 4. Interfaces

### 4.1 APIs Exposed

[List APIs this component provides.]

#### Example: GET /sync/status
```
Request:
  GET /api/v1/sync/status?store_id=STORE-001

Response (200 OK):
{
  "queue_size": 1250,
  "last_sync_timestamp": "2026-07-02T10:15:00Z",
  "status": "syncing",
  "pending_events": 1250
}
```

[Reference to relevant *_API_Spec.md]

### 4.2 Dependencies / Consumed APIs

[What external APIs does this component call?]

Example:
- `POST /api/v1/cloud/events` (to cloud sync agent)
- `GET /api/v1/inventory/{product_id}` (to inventory service)

### 4.3 Event Contracts

[If publishing events, describe the schema.]

Example:
```json
{
  "event_id": "EVT-123456",
  "event_type": "TransactionCompleted",
  "timestamp": "2026-07-02T10:15:00Z",
  "data": {
    "transaction_id": "TX-789",
    "amount": 150.00,
    "items_count": 3
  }
}
```

## 5. Data Models & Schemas

[Reference the SQL DDL or database schema for this component.]

### 5.1 Key Tables/Collections
- `table_name`: [Purpose, key columns]
- `another_table`: [Purpose, key columns]

[Link to relevant *_DDL.sql file]

### 5.2 Caching Strategy

[If applicable, describe caching (in-memory, Redis, local store).]

Example:
- **Product Cache:** 24-hour TTL, updated hourly
- **Inventory Cache:** 5-minute TTL, invalidated on write
- **Feature Store:** Per-transaction (no caching)

## 6. Deployment & Operations

### 6.1 Deployment Topology

[Where does this component run? How is it scaled?]

Example:
- **POS:** On-device (Windows .NET / Android)
- **Store Edge:** Kubernetes pod (1 replica per store)
- **Cloud:** AKS (3 replicas, auto-scale 1-10)

### 6.2 Configuration Management

[How is this component configured? Environment variables? ConfigMaps?]

Example:
```
Environment Variables:
├─ SYNC_INTERVAL_SECONDS: 300
├─ MAX_QUEUE_SIZE: 100000
├─ CLOUD_API_URL: https://cloud.retailai.com
└─ RETRY_MAX_ATTEMPTS: 5
```

### 6.3 Monitoring & Observability

[What metrics, logs, and alerts are important?]

| Metric | Type | Alert Threshold |
|---|---|---|
| `sync_queue_size` | Gauge | > 50,000 events |
| `sync_latency_ms` | Histogram (p99) | > 5000 ms |
| `sync_failures` | Counter | > 10 per minute |
| `crdt_merge_conflicts` | Counter | > 100 per hour |

### 6.4 SLAs & Performance

| SLA | Target | Measurement |
|---|---|---|
| **Availability** | 99.9% | Uptime monitoring |
| **Sync Latency (p99)** | <5 seconds | APM traces |
| **Queue Growth Rate** | <1000 events/min | Metrics |
| **Recovery Time (RTO)** | <1 hour | Incident response |

## 7. Testing Strategy

### 7.1 Unit Tests
[What are unit tested? (algorithms, state machines, business logic)]

### 7.2 Integration Tests
[Test interactions with dependencies (APIs, databases)]

### 7.3 End-to-End Tests
[Test complete flows (POS → Store → Cloud, offline scenarios)]

### 7.4 Load / Stress Tests
[Test under peak load (e.g., 3-day outage recovery with 50K events)]

## 8. Security Considerations

[Security relevant to this component]

Example:
- Authentication: mTLS for gRPC, OAuth 2.0 for REST
- Authorization: Role-based access control (RBAC)
- Encryption: AES-256 for data at rest, TLS 1.3 for data in transit
- Secrets: API keys stored in Azure Key Vault

## 9. References

### Related ADRs
- [ADR-XXX relevant to this design, e.g., ADR-006 for CRDT conflict resolution]

### Related HLDs
- [HLD-XXX that this LLD implements, e.g., HLD-010 for offline architecture]

### Related LLDs
- [LLD-YYY related to this LLD, e.g., LLD-001 uses LLD-002 for sync]

### API Specifications
- [*_API_Spec.md if applicable]

### Database Schemas
- [*_DDL.sql if applicable]

### External References
- [Academic papers, RFC, or standards if relevant, e.g., CRDT paper by Shapiro et al.]
```

## Key Guidelines

### 1. **Go Deep, but Stay Focused**
- LLD = component or service level
- Explain algorithms and state machines (not code, but pseudocode OK)
- Explain data structures and caching strategies

### 2. **Include Detailed Diagrams**
- Component diagrams with clear responsibilities
- Data flow diagrams showing request/response cycles
- State machines if applicable
- Sequence diagrams for complex interactions

### 3. **Reference APIs & Schemas**
- Link to *_API_Spec.md files
- Link to *_DDL.sql files
- Quote actual request/response examples

### 4. **Cover Operations**
- How is this deployed? (Docker, Kubernetes, serverless?)
- How is it configured? (environment variables, ConfigMaps?)
- What are the SLAs? (latency, availability, throughput?)
- How is it monitored? (metrics, logs, alerts?)

### 5. **Explain Performance**
- Caching strategies (TTL, invalidation)
- Batch vs. streaming (when and why?)
- Scalability considerations (horizontal, vertical?)

## LLD-to-HLD Mapping

Each LLD details one or more HLDs:

| LLD | Topic | Parent HLD |
|---|---|---|
| LLD-001 | Transaction Engine | HLD-002 (POS) |
| LLD-002 | Offline Sync Agent | HLD-010 (Offline) |
| LLD-003 | Store Edge Orchestration | HLD-003 (Store Edge) |
| LLD-004 | Fraud Detection | HLD-005 (AI/ML) |
| LLD-010 | Tenant Provisioning | HLD-009 (Multitenancy) |
| LLD-013 | Data Schema Design | HLD-006 (Data), HLD-009 (Multitenancy) |
| LLD-014 | API Design | HLD-008 (Integration) |
| LLD-015 | MLOps Pipeline | HLD-005 (AI/ML) |

## Naming Convention

File: `LLD-###_[Descriptive_Title_In_PascalCase].md`

Examples:
- ✅ `LLD-001_POS_Transaction_Engine.md`
- ✅ `LLD-011_Event_Sync_CRDT_Engine.md`
- ❌ `LLD 1 - Transaction Engine.md`

## Section Checklist

- [ ] **Purpose** — One paragraph on component responsibility
- [ ] **Architecture Overview** — Detailed diagrams
- [ ] **Detailed Design** — Algorithms, state machines, modules
- [ ] **Interfaces** — APIs, events, dependencies (with examples)
- [ ] **Data Models** — Schemas, caching (links to DDL)
- [ ] **Deployment & Operations** — Where, how, SLAs, monitoring
- [ ] **Testing Strategy** — Unit, integration, E2E, load tests
- [ ] **Security** — Authentication, authorization, encryption
- [ ] **References** — Links to ADRs, HLDs, APIs, schemas

## Examples in This Repository

- [LLD-001_POS_Transaction_Engine.md](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md) — Transaction state machine
- [LLD-011_Event_Sync_CRDT_Engine.md](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md) — Conflict resolution
- [LLD-015_MLOps_Pipeline_Design.md](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md) — Model training pipelines

---

**See [AGENTS.md](AGENTS.md) for navigation to all LLDs.**
```
