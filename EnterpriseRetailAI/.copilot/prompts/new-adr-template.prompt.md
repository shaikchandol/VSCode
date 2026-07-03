---
kind: prompt
name: new-adr-template
description: Template for creating new Architecture Decision Records (ADRs) following Michael Nygard format and project conventions
applyTo:
  - "**/*ADR*.md"
  - "EnterpriseRetailAI-Docs/ADR-*.md"
---

# Architecture Decision Record (ADR) Template

Use this template when proposing a new architecture decision or superseding an existing one.

## Before You Start

1. **Check existing ADRs** — See [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md) for all current decisions
2. **Identify the need** — What architectural question does this ADR answer?
3. **Gather context** — What forces/constraints exist? (business, technical, compliance)
4. **Document options** — What alternatives did you consider?
5. **Get ARB review** — Submit for Architecture Review Board approval before marking as Approved

## ADR Template

```markdown
# ADR-XXX — [Decision Title]

| Attribute | Value |
|---|---|
| Document ID | ADR-XXX |
| Type | Architecture Decision Record |
| Version | 1.0 |
| Status | Proposed |
| Author | [Your Name] |
| Date | [Month Year] |
| Supersedes | [Previous ADR ID, if any] |

## 1. Context

[Provide the situation that prompted this decision. What problem are we solving?]

### Forces / Constraints
- **Business Constraint 1:** [e.g., "POS terminals must work offline indefinitely"]
- **Technical Constraint 2:** [e.g., "ONNX Runtime is 50% smaller than TensorFlow"]
- **Compliance Constraint 3:** [e.g., "GDPR requires schema-per-tenant isolation"]

### Alternatives Considered
1. **Option A:** [Explanation, trade-offs]
2. **Option B:** [Explanation, trade-offs]
3. **Option C:** [Explanation, trade-offs, why rejected]

## 2. Decision

[State the decision clearly. Use active voice: "We will...".]

Example: "We will use schema-per-tenant isolation for multitenancy, with each tenant occupying a separate PostgreSQL schema."

## 3. Consequences

### Positive Consequences (Benefits)
- ✅ [Benefit 1, e.g., "GDPR compliance: data deletion is trivial (DROP SCHEMA)"]
- ✅ [Benefit 2, e.g., "Performance isolation: each schema has independent indexes"]
- ✅ [Benefit 3, e.g., "Tenant customization: custom fields per schema without impact"]

### Negative Consequences (Trade-offs)
- ❌ [Trade-off 1, e.g., "Cross-tenant reporting requires UNION queries"]
- ❌ [Trade-off 2, e.g., "More schema management overhead (provisioning, migration)"]
- ❌ [Trade-off 3, e.g., "Maximum ~1000 tenants per database (schema limit)"]

### Mitigation Strategies
- For negative consequence 1: [How do we mitigate?]
- For negative consequence 2: [How do we mitigate?]

## 4. Implementation Path

[If applicable, outline how this decision will be implemented.]
- Phase 1: [First steps, timeline]
- Phase 2: [Follow-up steps, timeline]
- Phase 3: [Completion and validation]

## 5. References

- [Link to related HLD, e.g., HLD-009_Multitenancy.md]
- [Link to related LLD, e.g., LLD-010_Tenant_Provisioning_Service.md]
- [Link to related API spec, e.g., Tenant_Admin_API_Spec.md]
- [Link to schema DDL, e.g., tenant_schema_DDL.sql]
- [Link to other ADRs if superseded, e.g., ADR-001]

## 6. Approval Status

- [ ] Architecture Review Board (ARB) Approval Required
- [ ] Legal/Compliance Review (if compliance decision)
- [ ] Security Team Review (if security decision)
- Status: Proposed → [Approved/Rejected]
```

## Key Guidelines

### 1. **Write for Clarity**
- Assume the reader knows the domain but not the specific decision
- Use concrete examples, not abstract language
- Define acronyms on first use

### 2. **Enumerate Consequences**
- List at least 2 positive and 2 negative
- Don't hide trade-offs; acknowledge them explicitly
- Explain why the positive consequences outweigh the negative

### 3. **Be Decisive**
- Don't use hedging language ("might," "could," "should")
- Use: "We will," "We choose," "We require"

### 4. **Cross-Reference**
- Link to HLDs/LLDs that implement this decision
- Link to API specs and schemas that exemplify this decision
- Link to any related ADRs

### 5. **Supersession**
- If overturning an existing ADR, cite it in "Supersedes"
- Explain what changed (business, technical, compliance context)
- New ADR coexists with old (no deletion)

## Naming Convention

File: `ADR-###_[Descriptive_Title_In_PascalCase].md`

Examples:
- ✅ `ADR-002_Schema_Per_Tenant.md`
- ✅ `ADR-005_ONNX_POS_Inference.md`
- ❌ `ADR 2 - Schema Per Tenant.md` (spaces, wrong format)

## Review Process

1. **Author submits** ADR in "Proposed" status
2. **ARB reviews** Context, Decision, Consequences for completeness
3. **ARB approves** or requests revisions
4. **Status changes to "Approved"** once ARB votes to accept
5. **Document is immutable** — no updates, only supersession

## Examples in This Repository

- [ADR-003_Event_Sourcing.md](EnterpriseRetailAI-Docs/ADR-003_Event_Sourcing.md)
- [ADR-006_CRDT_Conflict_Resolution.md](EnterpriseRetailAI-Docs/ADR-006_CRDT_Conflict_Resolution.md)
- [ADR-007_P2PE_Payment.md](EnterpriseRetailAI-Docs/ADR-007_P2PE_Payment.md)

---

**See [ADR_Index.md](EnterpriseRetailAI-Docs/ADR_Index.md) for all current ADRs and approval timeline.**
```
