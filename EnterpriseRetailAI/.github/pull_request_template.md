## Description

[Describe the documentation changes: new ADR, updated HLD, new LLD, etc.]

## Document Type

- [ ] ADR (Architecture Decision Record)
- [ ] HLD (High-Level Design)
- [ ] LLD (Low-Level Design)
- [ ] API Specification
- [ ] Database Schema (DDL)
- [ ] Configuration / MLOps
- [ ] Reference Guide / Navigation
- [ ] Other: [describe]

## Document Checklist

**Required for all documents:**
- [ ] Metadata header present (Document ID, Type, Version, Status, Author, Date)
- [ ] Document follows naming convention (HLD-###_*, LLD-###_*, ADR-###_*, etc.)
- [ ] All internal links are relative paths and point to existing files
- [ ] References section includes links to related docs
- [ ] No broken links (validated by GitHub Actions)

**For ADRs only:**
- [ ] Includes Context section (problem, forces, constraints)
- [ ] Includes Decision section (clear, active voice)
- [ ] Includes Consequences section (positive and negative)
- [ ] Includes "Supersedes" field if overturning a previous ADR

**For HLDs only:**
- [ ] Includes Purpose section (scope and level of detail)
- [ ] Includes Architecture Diagram or System Context
- [ ] Includes Design Rationale (references relevant ADRs)
- [ ] Includes Quality Attributes / SLAs
- [ ] References at least one supporting LLD

**For LLDs only:**
- [ ] Includes Architecture Overview with detailed diagrams
- [ ] Includes Detailed Design (algorithms, state machines, modules)
- [ ] Includes Interfaces (APIs, events, dependencies with examples)
- [ ] Includes Data Models section (links to DDL)
- [ ] Includes Deployment & Operations (topology, config, SLAs)
- [ ] Includes Testing Strategy
- [ ] References parent HLD

**For Database Schemas (DDL):**
- [ ] Includes purpose header and version
- [ ] All tables have comments explaining business logic
- [ ] Primary keys and foreign keys defined
- [ ] Indexes created for frequently queried columns
- [ ] Migration comments included if modifying existing schema

**For API Specifications:**
- [ ] Authentication & authorization documented
- [ ] All endpoints defined with methods, paths, status codes
- [ ] Request/response schemas included (JSON Schema or Protobuf)
- [ ] Rate limits and quotas specified
- [ ] Error codes documented with recovery strategies

## Navigation Updates

- [ ] Updated AGENTS.md with new document navigation (if applicable)
- [ ] Updated QUICK_REFERENCE.md (if high-level change affecting overview)
- [ ] Updated ADR_Index.md status (if submitting new ADR)
- [ ] Updated related HLD/LLD references to link to new doc

## Validation

- [ ] Ran `./validate-docs.sh --verbose` locally and resolved all warnings/errors
- [ ] Verified markdown links with `markdownlint`
- [ ] Cross-checked against `.doc-rules` validation rules
- [ ] Updated `DOCUMENT_MANIFEST.md` if adding or changing documentation artifacts
- [ ] Confirmed `.copilot/skills/` references are correct for new agent guidance
- [ ] Confirmed TOGAF ADM alignment (phase letter, section structure)

## Governance (if applicable)

- [ ] **For ADRs:** Submitted for Architecture Review Board (ARB) approval
  - ARB Review Status: [Pending / Approved / Needs Revision]
  - Expected approval date: [YYYY-MM-DD]

- [ ] **For compliance-related docs:** Reviewed by Legal/Compliance team
  - Compliance Review Status: [Pending / Approved]

- [ ] **For security-related docs:** Reviewed by Security team
  - Security Review Status: [Pending / Approved]

## Related Issues / PRs

- Closes #[issue number] (if applicable)
- Relates to PR #[number] (if applicable)

## Additional Context

[Any additional context, screenshots, or notes for reviewers]

---

## ✅ Before Submitting

- [ ] No merge conflicts with main branch
- [ ] All required checkboxes above are completed
- [ ] GitHub Actions validation workflow passes
- [ ] Documentation is clear and follows project conventions
- [ ] All hyperlinks are tested and functional

**For questions about documentation standards, see [.doc-rules](.doc-rules) and [GETTING_STARTED.md](GETTING_STARTED.md).**
