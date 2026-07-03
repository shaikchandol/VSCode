# SKILL.md — Analyze Architecture Decisions

**Skill Name:** analyze-architecture-decisions

**Purpose:** Help AI agents search, compare, and explain architecture decisions by quickly locating relevant ADRs and synthesizing their context, decisions, and consequences.

---

## When to Use This Skill

Use this skill when:
- **Comparing design alternatives** — "Should we use ONNX or TensorFlow for edge inference?"
- **Understanding decision rationale** — "Why did the team choose schema-per-tenant isolation?"
- **Assessing consequences** — "What are the trade-offs of using CRDT for conflict resolution?"
- **Tracing decision evolution** — "Have any decisions been superseded? What changed?"
- **Architectural guidance** — "What are the key decisions that shape how we build payment systems?"

Do NOT use this skill for:
- General architecture questions (use AGENTS.md navigation instead)
- Implementation details (use HLD/LLD documents)
- Code-level decisions (use codebase search)

---

## Workflow

### Step 1: Identify the Decision Domain
Map the user's question to one of the 8 ADRs:

| Domain | ADR | Decision |
|---|---|---|
| **Cloud Platform** | ADR-001 | Why Azure over AWS/GCP? |
| **Data Isolation** | ADR-002 | Why schema-per-tenant over RLS? |
| **Transaction State** | ADR-003 | Why event sourcing over CRUD? |
| **Store Edge Orchestration** | ADR-004 | Why K3s over Docker Compose/Kubernetes? |
| **POS Edge AI** | ADR-005 | Why ONNX over TensorFlow/TFLITE? |
| **Offline Conflict Resolution** | ADR-006 | Why CRDT over last-write-wins? |
| **Payment Processing** | ADR-007 | Why P2PE tokenization? |
| **NLP Assistant** | ADR-008 | Why GPT-4o + RAG over fine-tuned models? |

### Step 2: Locate and Summarize the ADR
Read the relevant ADR file (e.g., [ADR-002_Schema_Per_Tenant.md](EnterpriseRetailAI-Docs/ADR-002_Schema_Per_Tenant.md)) and extract:
- **Context:** What forces were at play? What constraints existed?
- **Decision:** What was chosen? Why that option?
- **Consequences:** What are the positive and negative outcomes?

### Step 3: Cross-Reference Supporting Documents
Use this map to find related HLDs/LLDs:

| ADR | Primary Support | Secondary Support |
|---|---|---|
| ADR-001 (Azure) | [HLD-004](EnterpriseRetailAI-Docs/HLD-004_Cloud_Platform_Azure.md) | [HLD-001](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md) |
| ADR-002 (Schema-per-tenant) | [HLD-009](EnterpriseRetailAI-Docs/HLD-009_Multitenancy.md), [LLD-010](EnterpriseRetailAI-Docs/LLD-010_Tenant_Provisioning_Service.md), [LLD-013](EnterpriseRetailAI-Docs/LLD-013_Data_Schema_Design.md) | [tenant_schema_DDL.sql](EnterpriseRetailAI-Docs/tenant_schema_DDL.sql) |
| ADR-003 (Event Sourcing) | [LLD-001](EnterpriseRetailAI-Docs/LLD-001_POS_Transaction_Engine.md), [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md) | [pos_local_sqlite_DDL.sql](EnterpriseRetailAI-Docs/pos_local_sqlite_DDL.sql), [LLD-011](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md) |
| ADR-004 (K3s) | [HLD-003](EnterpriseRetailAI-Docs/HLD-003_Store_Edge_Platform.md), [LLD-003](EnterpriseRetailAI-Docs/LLD-003_Store_Edge_Orchestration.md) | [HLD-001](EnterpriseRetailAI-Docs/HLD-001_System_Architecture_Overview.md) |
| ADR-005 (ONNX) | [LLD-004](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md), [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) | [HLD-002](EnterpriseRetailAI-Docs/HLD-002_POS_Application.md) |
| ADR-006 (CRDT) | [LLD-011](EnterpriseRetailAI-Docs/LLD-011_Event_Sync_CRDT_Engine.md), [HLD-010](EnterpriseRetailAI-Docs/HLD-010_Offline_Architecture.md) | [LLD-002](EnterpriseRetailAI-Docs/LLD-002_Offline_Sync_Agent.md) |
| ADR-007 (P2PE) | [LLD-012](EnterpriseRetailAI-Docs/LLD-012_Payment_Service.md) | [HLD-007](EnterpriseRetailAI-Docs/HLD-007_Security_Compliance.md) |
| ADR-008 (GPT-4o + RAG) | [LLD-008](EnterpriseRetailAI-Docs/LLD-008_NLP_Store_Assistant.md) | [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) |

### Step 4: Synthesize and Answer
Combine the ADR context, decision, and consequences with supporting docs to answer the user's question. Always:
- Cite the ADR ID and date
- Quote the decision rationale from the ADR context section
- Mention both positive and negative consequences
- Reference supporting HLDs/LLDs for implementation details

---

## Example: Comparing ONNX vs. TensorFlow for POS Edge

**User Question:** "Why do we use ONNX instead of TensorFlow for the POS fraud detection model?"

**Step 1–2:** Read [ADR-005_ONNX_POS_Inference.md](EnterpriseRetailAI-Docs/ADR-005_ONNX_POS_Inference.md)

**Step 3:** Cross-reference:
- [LLD-004_Fraud_Detection_Service.md](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md) — Fraud model pipeline and scoring
- [HLD-005_AI_ML_Platform.md](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) — Overall AI/ML architecture

**Step 4:** Synthesize response:

> **Answer:** According to ADR-005 (ONNX Runtime for POS Edge AI Inference, approved Feb 2026), the team chose ONNX over TensorFlow for edge inference because:
>
> **Context:** POS terminals must infer fraud scores in <100ms with minimal latency variance. Inference runs offline with no network access.
>
> **Decision:** Use ONNX Runtime 1.17+ with quantized XGBoost models for all edge deployments (POS and Store Edge).
>
> **Key Consequences:**
> - ✅ **Positive:** Portable across Windows .NET and Android; sub-50ms inference latency; minimal model size (~5MB)
> - ❌ **Negative:** Limited to supported model architectures (no custom operators); no AutoML integration
>
> **Implementation:** See [LLD-004](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md) for the fraud detection pipeline, which trains XGBoost in Azure ML and exports to ONNX format for POS deployment.

---

## Cross-Decision Dependencies

Some decisions depend on others. Track these relationships:

- **ADR-002 → ADR-003:** Schema-per-tenant + Event sourcing = multi-tenant audit trail
- **ADR-003 → ADR-006:** Event sourcing + CRDT = offline conflict resolution without manual merge
- **ADR-005 → LLD-004 through LLD-009:** ONNX edge inference drives all AI use case deployment
- **ADR-001 → ADR-008:** Azure cloud platform enables Azure OpenAI for NLP assistant

When comparing decisions, mention related ADRs to show how the architecture is cohesive.

---

## Supersession & Deprecation

As of June 2026:
- **All ADRs (ADR-001 through ADR-008) are active (Approved status)**
- **No superseded ADRs** — No decisions have been overturned
- If a decision is superseded in the future, the new ADR will explicitly reference the old ADR in its "Supersedes" field

Always check the ADR_Index.md status column for any deprecated decisions before citing.

---

## Quick Reference: Decision Timeline

| Date | ADR | Decision |
|---|---|---|
| Jan 2026 | ADR-001, 002, 003, 007 | Core platform decisions (Azure, multitenancy, event sourcing, P2PE) |
| Feb 2026 | ADR-004, 005 | Deployment decisions (K3s, ONNX) |
| Mar 2026 | ADR-006, 008 | Offline & NLP decisions (CRDT, Azure OpenAI) |

Check document dates for when decisions were frozen and implementation began.

---

## When You Don't Know the Answer

If a user asks about a decision not covered by the 8 ADRs:
1. Check if the question belongs in the HLD/LLD domain instead (use [AGENTS.md](AGENTS.md))
2. If a decision exists but the ADR is missing, note this as a gap and suggest creating one
3. Point the user to the most relevant existing ADR (e.g., "ADR-001 covers cloud platform choices")

---

## Tips for Agents

1. **Always read the full ADR** — Don't summarize from the index alone; dive into context, decision, and consequences
2. **Cite specific dates** — ADRs are timestamped; this shows decision stability or recency
3. **Connect to implementation** — After explaining the decision, link to how it's implemented in HLDs/LLDs
4. **Acknowledge trade-offs** — Every decision has costs; mention both positive and negative consequences
5. **Check status first** — Before citing an ADR, verify it's "Approved" in [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md)
