# GLOSSARY.md — EnterpriseRetailAI Domain Terminology

**Last Updated:** July 2026 | **Audience:** All stakeholders (architects, developers, business users)

---

## A

### ADR
**Architecture Decision Record** — A document capturing a significant architecture decision, including context, decision, and consequences. ADRs are immutable; superseded decisions create new ADRs rather than updating existing ones.

**Examples:** [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [ADR-006_CRDT_Conflict_Resolution.md](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md)

**See Also:** ARB

### ARB
**Architecture Review Board** — Governing body responsible for approving ADRs and architectural decisions. Must review all ADRs before "Approved" status.

### Append-Only Log
**Immutable transaction log** where new entries are always added to the end and old entries never deleted or modified. Used for event sourcing at POS and store edge levels.

**Example:** POS local SQLite event log (never deletes events, only marks as synced)

**See Also:** Event Sourcing

---

## B

### Batch Processing
**Asynchronous processing of events in groups** rather than individually. Used for POS → Store Edge sync (every 5 minutes) and Store Edge → Cloud sync (continuous streaming via Event Hubs).

**See Also:** Event Hubs, Streaming

---

## C

### CCPA
**California Consumer Privacy Act** — US privacy law requiring data export, deletion, and opt-out mechanisms. Implemented in [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md).

**See Also:** GDPR, DPDP, PIPL, Compliance

### Cloud
**Azure multi-region cloud infrastructure** hosting AKS (Kubernetes), Event Hubs, Azure ML, Azure SQL, APIM. The centralized, highly available tier of the three-tier architecture.

**Counterparts:** POS Edge, Store Edge

**See Also:** HLD-004

### Compliance
**Meeting legal and regulatory requirements** including GDPR, CCPA, DPDP, PIPL, and PCI-DSS. Enforced through design decisions (e.g., schema-per-tenant for GDPR) and operational procedures.

**Reference:** [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)

### CRDT
**Conflict-free Replicated Data Type** — A mathematical data structure allowing concurrent updates across multiple replicas without coordination, automatically merging conflicts into a consistent state.

**Use Case:** Merging offline edits from Store A and Store B when they reconnect.

**Example:** If Store A sells 5 items and Store B sells 3 items (both offline), CRDT merges to -8 net (both operations applied automatically).

**Reference:** [ADR-006_CRDT_Conflict_Resolution.md](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md), [LLD-011_Event_Sync_CRDT_Engine.md](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md)

---

## D

### DPDP
**Digital Personal Data Protection Act** — Indian privacy law. Requires data residency and data processing consent. Implemented in [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) via regional schema placement.

**See Also:** GDPR, CCPA, PIPL

### Drift Monitoring
**Continuous observation of model performance metrics** to detect data distribution changes (feature drift), prediction changes (prediction drift), or label changes (label drift). Triggers retraining if threshold exceeded.

**Drift Types:**
- **Feature Drift:** Input distribution changes (e.g., average transaction amount increases 20%)
- **Prediction Drift:** Model output distribution changes (e.g., fraud scores shift 10%)
- **Label Drift:** Ground truth distribution changes (e.g., fraud rate in labeled data changes)

**Reference:** [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md)

---

## E

### ERP
**Enterprise Resource Planning** — System for managing business processes (finance, HR, procurement). Example: SAP. Integrated via REST API for product master, pricing, and GL posting.

**See Also:** Integration, API

### Event Hubs
**Azure Event Hubs** — Distributed message broker (pub-sub) for streaming events from Store Edge to Cloud. Guarantees ordering per partition and exactly-once delivery.

**Used For:** Transaction stream, inventory updates, ML training data

**See Also:** Streaming, Batch Processing

### Event Log
**Append-only sequence of events** representing all changes to the system. Single source of truth in event sourcing architecture.

**Example:** POS terminal logs TransactionCreated, ItemAdded, ItemRemoved, TransactionCompleted events.

**See Also:** Event Sourcing, Append-Only Log

### Event Sourcing
**Architectural pattern where all changes to application state are captured as a sequence of immutable events.** Rather than storing current state (CRUD), store all state-changing events and derive current state by replaying events.

**Benefits:** Audit trail (full history), offline recovery (replay events), temporal queries (state at any point in time)

**Reference:** [ADR-003_Event_Sourcing.md](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md), [LLD-001_POS_Transaction_Engine.md](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md)

---

## F

### Feature Store
**Centralized repository of computed features** (derived data) used for ML model training and inference. Examples: customer lifetime value, average transaction amount, fraud risk score.

**Locations:**
- **Cloud:** Azure ML Feature Store (training, batch inference)
- **Store Edge:** Local cache for real-time inference and offline fallback
- **POS:** No feature store (pre-computed models)

**See Also:** AI/ML, ONNX

### FX Rates
**Foreign Exchange rates** used for dynamic pricing in multi-currency environments. Synced hourly from market data provider (e.g., FXData API).

**See Also:** Integration, Market Data

---

## G

### GDPR
**General Data Protection Regulation** — EU privacy law requiring data protection, deletion, and portability. Implemented via:
- Schema-per-tenant isolation (easy GDPR deletion)
- Data export API
- 30-day deletion SLA

**Reference:** [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)

---

## H

### HLD
**High-Level Design** — Architecture documentation at the layer or domain level (e.g., HLD-002 for POS Application, HLD-005 for AI/ML Platform).

**Counterpart:** LLD

**Examples:** [HLD-001_System_Architecture_Overview.md](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md), [HLD-010_Offline_Architecture.md](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md)

---

## I

### Idempotency
**Property of an operation that produces the same result whether executed once or multiple times.** Critical for async systems where messages can be processed more than once.

**Example:** POS queues payment token three times due to network retry; each attempt must result in single token, not three.

**Implementation:** Event ID + deduplication at receiver, or operations designed to be naturally idempotent (e.g., SET instead of INCREMENT).

### Integration
**Connection between EnterpriseRetailAI and external systems** (ERP, WMS, CRM, payment gateways, market data). Patterns include REST, gRPC, Event Hubs, webhooks, and offline queues.

**Reference:** [HLD-008_Integration_Architecture.md](EnterpriseRetailAI-Docs/HLD-008_Integration_Architecture.md), [LLD-014_API_Design.md](EnterpriseRetailAI-Docs/LLD-014_API_Design.md)

---

## K

### K3s
**Lightweight Kubernetes** — Minimal Kubernetes distribution used for Store Edge orchestration. Chosen for edge deployment (low resource overhead, easy setup).

**Reference:** [ADR-004_K3s_Store_Edge.md](EnterpriseRetailAI-Docs/ADR-004_K3s_Store_Edge.md), [HLD-003_Store_Edge_Platform.md](EnterpriseRetailAI-Docs/HLD-003_Store_Edge_Platform.md)

---

## L

### LLD
**Low-Level Design** — Architecture documentation at the component/service level (e.g., LLD-001 for POS Transaction Engine, LLD-011 for CRDT Sync Engine).

**Counterpart:** HLD

**Examples:** [LLD-001_POS_Transaction_Engine.md](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md), [LLD-011_Event_Sync_CRDT_Engine.md](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md)

---

## M

### Multitenancy
**Architecture supporting multiple independent customers (tenants) in a single platform.** EnterpriseRetailAI uses schema-per-tenant isolation (separate PostgreSQL schema per tenant).

**Benefits:** Isolation, compliance, customization, performance

**Reference:** [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md), [HLD-009_Multitenancy.md](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md), [LLD-010_Tenant_Provisioning_Service.md](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md)

---

## O

### Offline Mode
**Operation without connectivity** to higher tiers (Store Edge, Cloud). POS terminal can operate indefinitely offline; Store Edge can operate 2-3 weeks offline.

**Data Persistence:** Append-only event log (never lost)

**Sync on Reconnect:** Batch pull (POS→Store) or streaming (Store→Cloud) resumes automatically

**Reference:** [HLD-010_Offline_Architecture.md](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md)

### ONNX
**Open Neural Network Exchange** — Open format for serializing trained ML models, enabling portable inference across platforms (Windows, Android, Edge devices).

**Use Case:** Fraud detection, CV self-checkout, promo ranking (all run on POS or Store Edge in ONNX format)

**Advantages:** <50MB model size, <100ms inference, offline-capable, no dependencies on TensorFlow/PyTorch at runtime

**Reference:** [ADR-005_ONNX_POS_Inference.md](EnterpriseRetailAI-Docs/ADR-005_ONNX_POS_Inference.md), [LLD-004_Fraud_Detection_Service.md](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md)

---

## P

### P2PE
**Point-to-Point Encryption** — Payment processing standard where card data is encrypted at the point of swipe (payment terminal) and never visible to POS system.

**Benefit:** PCI-DSS compliance (POS never stores card data)

**Flow:** Customer swipes → Hardware tokenises → POS sees only token → Token sent to payment gateway for authorization

**Reference:** [ADR-007_P2PE_Payment.md](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md), [LLD-012_Payment_Service.md](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md)

### PCI-DSS
**Payment Card Industry Data Security Standard** — Compliance requirement for payment systems. Enforced via P2PE tokenisation (no card data stored in POS).

**Reference:** [ADR-007_P2PE_Payment.md](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md), [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)

### POS
**Point of Sale** — Physical terminal (Windows .NET or Android device) where retail transactions occur. Bottom tier of three-tier architecture.

**Capabilities:** Transaction processing, inventory management, payment, local AI inference, offline operation (indefinite)

**See Also:** POS Edge, Store Edge, Cloud

### POS Edge
**Device Edge** — Same as POS tier (terminology used in three-tier context).

---

## R

### RAG
**Retrieval Augmented Generation** — AI technique combining retrieval (search customer docs/FAQs) + generation (LLM answer) for contextual AI responses.

**Use Case:** NLP Store Assistant (answers customer questions using product docs and customer history)

**Reference:** [LLD-008_NLP_Store_Assistant.md](EnterpriseRetailAI-Docs/LLD-008_NLP_Store_Assistant.md), [ADR-008_Azure_OpenAI_NLP.md](EnterpriseRetailAI-Docs/ADR-008_Azure_OpenAI_NLP.md)

---

## S

### Schema-Per-Tenant
**Multitenancy isolation model where each tenant occupies a separate PostgreSQL schema.** Not row-level security alone.

**Benefits:** GDPR compliance, performance isolation, schema customization

**Alternative:** Row-Level Security (RLS) — rejected due to compliance gaps

**Reference:** [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md)

### Streaming
**Continuous, real-time processing of events** as they arrive (vs. batch processing in groups). Used for Store Edge → Cloud sync via Event Hubs.

**See Also:** Event Hubs, Batch Processing

### Store
**Physical retail location** within a tenant's network. A store has POS terminals and a local Store Edge server.

### Store Edge
**On-premises server** at a retail location, running K3s, PostgreSQL, IoT Edge, local AI models, and sync agent. Middle tier of three-tier architecture.

**Capabilities:** Batch sync from POS, stream to cloud, local reporting, offline fallback AI

**See Also:** POS Edge, Cloud

### Sync
**Synchronization of events/data** from one tier to another. 
- **POS → Store:** Every 5 minutes (batched)
- **Store → Cloud:** Continuous streaming via Event Hubs
- **Offline → Online:** Automatic resume on reconnect (CRDT resolves conflicts)

**Reference:** [LLD-002_Offline_Sync_Agent.md](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md), [LLD-011_Event_Sync_CRDT_Engine.md](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md)

---

## T

### Tenant
**Independent customer** (franchise or geographic region) with isolated data and schema. Examples: "Europe Franchise," "North America Operations."

**Data Isolation:** Separate PostgreSQL schema per tenant (not RLS)

**See Also:** Schema-Per-Tenant, Multitenancy

### TensorFlow
**ML framework** (Google). Rejected for POS edge inference in favor of ONNX due to larger model size (~200MB) and runtime dependencies.

**See Also:** ONNX, ADR-005

### Three-Tier Architecture
**Deployment topology with three logical tiers:**
1. **POS Edge:** Device layer (indefinite offline)
2. **Store Edge:** On-premises layer (weeks offline)
3. **Cloud:** Centralized layer (always online)

**Key Property:** Each tier can operate offline; sync resumes automatically (CRDT resolves conflicts)

**Reference:** [HLD-001_System_Architecture_Overview.md](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md)

### TFT
**Temporal Fusion Transformer** — Deep learning time series forecasting model used for demand forecasting (predicts future SKU sales).

**Reference:** [LLD-005_Demand_Forecasting_Pipeline.md](EnterpriseRetailAI-Docs/LLD-005_Demand_Forecasting_Pipeline.md)

### TOGAF
**The Open Group Architecture Framework** — Enterprise architecture standard (version 10 ADM). Used to structure EnterpriseRetailAI documentation.

**Phases:** Vision (A) → Business (B) → Information Systems (C) → Technology (D) → Solutions (E) → Migration (F) → Governance (G) → Change Management (H)

**Reference:** [TOGAF_GlobalRetailPOS_EA_Document.md](EnterpriseRetailAI-Docs/TOGAF_GlobalRetailPOS_EA_Document.md)

---

## V

### Vector Clock
**Logical timestamp used to order events in distributed systems.** Enables CRDT to detect and merge concurrent edits from multiple offline replicas.

**Example:** Event from POS has vector clock [POS: 5, Store: 3]; Event from Store has [POS: 4, Store: 4]. Comparison determines causality.

**See Also:** CRDT, Event Sourcing

---

## W

### WMS
**Warehouse Management System** — System managing inventory, replenishment, shipping. Example: 3PL WMS. Integrated via gRPC streaming for real-time stock sync.

**See Also:** Integration, ERP

---

## Z

### Zero Trust
**Security model assuming no implicit trust; all access requests must be explicitly verified** via authentication, authorization, encryption, and least privilege.

**Implementation:** OAuth 2.0, mTLS, encryption, RBAC

**Reference:** [HLD-007_Security_Compliance.md](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md)

---

## Acronyms Quick Reference

| Acronym | Meaning |
|---|---|
| **ADR** | Architecture Decision Record |
| **API** | Application Programming Interface |
| **ARB** | Architecture Review Board |
| **CCPA** | California Consumer Privacy Act |
| **CRDT** | Conflict-free Replicated Data Type |
| **DPDP** | Digital Personal Data Protection Act |
| **ERP** | Enterprise Resource Planning |
| **GDPR** | General Data Protection Regulation |
| **gRPC** | gRPC Remote Procedure Call |
| **HLD** | High-Level Design |
| **K3s** | Lightweight Kubernetes |
| **LLD** | Low-Level Design |
| **ML** | Machine Learning |
| **mTLS** | Mutual TLS |
| **ONNX** | Open Neural Network Exchange |
| **P2PE** | Point-to-Point Encryption |
| **PCI-DSS** | Payment Card Industry Data Security Standard |
| **POS** | Point of Sale |
| **RAG** | Retrieval Augmented Generation |
| **RLS** | Row-Level Security |
| **SLA** | Service Level Agreement |
| **TFT** | Temporal Fusion Transformer |
| **TOGAF** | The Open Group Architecture Framework |
| **WMS** | Warehouse Management System |

---

**For term context and usage, see referenced HLDs/LLDs above. For navigation, see [AGENTS.md](AGENTS.md).**
