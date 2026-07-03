# Architecture Decision Records — Index
## EnterpriseRetailAI · All ADRs with Status & Summary

---

| Attribute | Value |
|---|---|
| Document | ADR Index |
| Version | 1.0 |
| Owner | Enterprise Architecture Office |
| Date | June 2026 |

---

## What is an ADR?

An Architecture Decision Record (ADR) documents a significant architectural decision made during the design of the EnterpriseRetailAI platform. Each ADR captures:
- **Context:** The situation and forces at play
- **Decision:** The choice made
- **Consequences:** What results from this decision (positive and negative)

ADRs are immutable — once approved, they are never deleted or overwritten. Superseded decisions create a new ADR referencing the original.

---

## ADR Index

| ADR ID | Title | Status | Approved |
|---|---|---|---|---|
| ADR-001 | Azure as Primary Cloud Platform | ✅ Approved | 2026-01 | — |
| ADR-002 | Schema-per-Tenant Isolation Model | ✅ Approved | 2026-01 | — |
| ADR-003 | Event Sourcing for Transaction State | ✅ Approved | 2026-01 | — |
| ADR-004 | K3s for Store Edge Orchestration | ✅ Approved | 2026-02 | — |
| ADR-005 | ONNX Runtime for POS Edge AI Inference | ✅ Approved | 2026-02 | — |
| ADR-006 | CRDT-based Offline Conflict Resolution | ✅ Approved | 2026-03 | — |
| ADR-007 | P2PE Payment Tokenisation at POS | ✅ Approved | 2026-01 | — |
| ADR-008 | Azure OpenAI GPT-4o + RAG for NLP Assistant | ✅ Approved | 2026-03 | — |

---

## ADR Status Definitions

| Status | Approved |
|---|---|
| ✅ Approved | Decision adopted; in production or planned for implementation |
| 🔄 Proposed | Under review by ARB |
| 🚫 Rejected | Considered but not adopted (kept for reference) |
| ⚠️ Deprecated | Superseded by a newer ADR |

---

## Related Documents

- TOGAF EA Document: `00_TOGAF/TOGAF_GlobalRetailPOS_EA_Document.md`
- System Architecture Overview: `01_HLD/HLD-001_System_Architecture_Overview.md`

