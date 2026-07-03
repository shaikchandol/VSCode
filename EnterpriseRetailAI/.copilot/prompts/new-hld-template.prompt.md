---
kind: prompt
name: new-hld-template
description: Template for creating new High-Level Designs (HLDs) covering layer, domain, or platform architecture
applyTo:
  - "**/*HLD*.md"
  - "EnterpriseRetailAI-Docs/HLD-*.md"
---

# High-Level Design (HLD) Template

Use this template when documenting architecture at the layer or domain level.

## Before You Start

1. **Identify the scope** — Are you documenting a layer (POS, Store, Cloud) or domain (Data, Security, AI/ML)?
2. **Align with system architecture** — See [HLD-001_System_Architecture_Overview.md](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md)
3. **Check existing docs** — Is this already documented? (avoid duplication)
4. **Plan drill-down** — What LLDs will detail this HLD?

## HLD Template

```markdown
# HLD-XXX — [Layer/Domain Name]

| Attribute | Value |
|---|---|
| Document ID | HLD-XXX |
| Type | High-Level Design |
| Version | 1.0 |
| Status | Approved |
| Author | Enterprise Architecture Office |
| Date | [Month Year] |

## 1. Purpose

[One paragraph: What does this HLD document? What level of detail?]

Example: "This document describes the POS terminal application architecture, including offline capabilities, transaction processing, local AI inference, and payment handling."

## 2. System Context / Component Diagram

[Include ASCII diagram or reference to Mermaid diagram showing how this layer fits in the broader system.]

### Context Diagram
```
┌─────────────────────────────────────────┐
│  [This Layer/Domain]                    │
│                                         │
│  ┌──────┐  ┌──────┐  ┌──────┐         │
│  │ Comp1│  │ Comp2│  │ Comp3│         │
│  └──────┘  └──────┘  └──────┘         │
│                                         │
└──────────────┬──────────────────────────┘
               │
        ┌──────▼───────┐
        │ Other Layer  │
        └──────────────┘
```

### Data Flow
[Show how data flows in/out of this layer]

## 3. Architecture Overview

[Describe the architectural structure at a high level.]

### Key Components
- **Component 1:** [Brief description, responsibility]
- **Component 2:** [Brief description, responsibility]
- **Component 3:** [Brief description, responsibility]

### Design Principles
- [Principle 1, e.g., "Offline-first: terminal operates independently"]
- [Principle 2, e.g., "Event sourcing: immutable audit trail"]

## 4. Design Rationale

[Why was this architecture chosen? Reference relevant ADRs.]

Example: "We chose schema-per-tenant isolation (ADR-002) because it provides GDPR compliance and performance isolation. This supports our multitenancy strategy (HLD-009) and enables schema customization per tenant."

## 5. Quality Attributes & SLAs

| Attribute | Target | How Measured |
|---|---|---|
| **Availability** | 99.5% uptime | Uptime monitoring per store |
| **Latency** | <100ms p99 | Application performance monitoring (APM) |
| **Throughput** | 1,000 txn/min per store | Load testing |
| **Scalability** | 10,000 stores | Capacity planning |
| **Security** | Zero Trust + encryption | Penetration testing, compliance audit |

## 6. Cross-Layer / Cross-Domain Interactions

[How does this layer/domain interact with adjacent layers/domains?]

### Incoming Dependencies
- [Layer/Component X sends data to this layer: explain flow]

### Outgoing Dependencies
- [This layer sends data to Layer/Component Y: explain flow]

### Integration Points
- [API endpoint or event topic, if applicable]

## 7. Deployment Topology

[Where does this layer run? How is it deployed?]

Example:
- **POS:** Windows .NET or Android device at store
- **Store Edge:** K3s cluster on on-premises server
- **Cloud:** AKS in Azure (multi-region)

## 8. References

### Architecture Decision Records
- [ADR-XXX relevant to this design, e.g., ADR-002 for multitenancy]

### Low-Level Designs (Implementation Details)
- [LLD-XXX that details this HLD, e.g., LLD-010 details HLD-009]
- [LLD-YYY another implementation]

### API Specifications
- [API spec if applicable, e.g., POS_API_Spec.md]

### Database Schemas
- [DDL file if applicable, e.g., tenant_schema_DDL.sql]

### Related HLDs
- [Complementary HLD, e.g., HLD-001 is system context]
```

## Key Guidelines

### 1. **Scope Clearly**
- HLD = layer or domain level
- Don't mix levels (don't go into component implementation)
- Reference LLDs for detailed implementation

### 2. **Include Architecture Diagrams**
- ASCII art or Mermaid diagrams are helpful
- Show component boundaries and interactions
- Include data flow or state diagrams if relevant

### 3. **Connect to Decisions**
- Mention which ADRs influenced this design
- Explain trade-offs (performance vs. simplicity, isolation vs. operational complexity)

### 4. **Define Quality Attributes**
- What are the performance, scalability, security, availability targets?
- How are they measured and monitored?

### 5. **Show Context**
- How does this fit in the broader system?
- What layers does it depend on? What depends on it?

## HLD-to-LLD Mapping

Each HLD should have 1-3 corresponding LLDs for detail:

| HLD | Topic | Related LLDs |
|---|---|---|
| HLD-001 | System Architecture | None (overview only) |
| HLD-002 | POS Application | LLD-001 (transaction engine), LLD-004-009 (AI use cases) |
| HLD-003 | Store Edge Platform | LLD-003 (orchestration), LLD-002 (sync) |
| HLD-004 | Cloud Platform | LLD-015 (MLOps), various cloud services |
| HLD-005 | AI/ML Platform | LLD-004-009 (each use case), LLD-015 (MLOps) |
| HLD-006 | Data Architecture | LLD-013 (schema design), DDL files |
| HLD-007 | Security & Compliance | LLD-012 (payments), various compliance measures |
| HLD-008 | Integration Architecture | LLD-014 (API design), *_API_Spec.md files |
| HLD-009 | Multitenancy | LLD-010 (provisioning), LLD-013 (schema) |
| HLD-010 | Offline Architecture | LLD-002 (sync), LLD-011 (CRDT) |

## Naming Convention

File: `HLD-###_[Descriptive_Title_In_PascalCase].md`

Examples:
- ✅ `HLD-001_System_Architecture_Overview.md`
- ✅ `HLD-005_AI_ML_Platform.md`
- ❌ `HLD 1 - System Architecture.md`

## Section Checklist

- [ ] **Purpose** — One paragraph on scope
- [ ] **System Context** — Diagram showing where this fits
- [ ] **Architecture Overview** — Components and design principles
- [ ] **Design Rationale** — Why? References to ADRs
- [ ] **Quality Attributes** — SLAs and performance targets
- [ ] **Cross-Layer Interactions** — How does it depend on/support other layers?
- [ ] **Deployment** — Where does it run?
- [ ] **References** — Links to ADRs, LLDs, APIs, schemas

## Examples in This Repository

- [HLD-001_System_Architecture_Overview.md](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md) — System context
- [HLD-005_AI_ML_Platform.md](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) — AI/ML domain
- [HLD-009_Multitenancy.md](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md) — Multitenancy pattern
- [HLD-010_Offline_Architecture.md](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md) — Offline-first pattern

---

**See [AGENTS.md](AGENTS.md) for navigation to all HLDs.**
```
