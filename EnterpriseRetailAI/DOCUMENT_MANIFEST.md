# DOCUMENT_MANIFEST.md

## Purpose
This manifest documents the main architecture artifacts, validation tools, GitHub workflow, Copilot skills, and authoring templates for EnterpriseRetailAI.

## Architecture Documentation
- `EnterpriseRetailAI-Docs/` — primary architecture content
  - `TOGAF_GlobalRetailPOS_EA_Document.md` — full enterprise architecture document
  - `HLD-001` through `HLD-010` — high-level design documents
  - `LLD-001` through `LLD-015` — low-level design documents
  - `ADR-001` through `ADR-008` — architecture decision records
  - `*_API_Spec.md` — API contracts for POS, store management, tenant admin, and inference
  - `*_DDL.sql` — database schema definitions
  - `MLOps_Pipeline_Config.md`, `Model_Cards.md`, `Drift_Monitoring_Config.md` — AI/ML and MLOps artifacts

## Root Guidance Files
- `README.md` — repository overview and entry point
- `GETTING_STARTED.md` — onboarding guide for contributors and AI agents
- `AGENTS.md` — document navigation guide for AI agents
- `QUICK_REFERENCE.md` — one-page architecture cheat sheet
- `GLOSSARY.md` — domain terminology and definitions
- `DOCUMENT_MANIFEST.md` — this file
- `SKILL_EXAMPLES.md` — sample prompts for Copilot skills
- `.doc-rules` — repository validation rules for docs

## Validation Tools
- `validate-docs.sh` — local documentation and schema validator
- `.github/workflows/validate-docs.yml` — PR validation workflow

## Copilot Skills
- `.copilot/skills/mlops-drift-analysis/SKILL.md`
- `.copilot/skills/multitenancy-isolation/SKILL.md`
- `.copilot/skills/offline-first-architecture/SKILL.md`
- `.copilot/skills/integration-architecture/SKILL.md`
- `.copilot/skills/security-compliance/SKILL.md`
- `.copilot/skills/data-architecture/SKILL.md`
- `.copilot/skills/performance-scaling/SKILL.md`

## Prompt Templates
- `.copilot/prompts/new-adr-template.prompt.md`
- `.copilot/prompts/new-hld-template.prompt.md`
- `.copilot/prompts/new-lld-template.prompt.md`

## GitHub Automation
- `.github/workflows/validate-docs.yml` — validates docs on PRs and comments results
- `.github/pull_request_template.md` — documentation PR checklist

## Notes
- Update this manifest whenever new architecture documents, validation scripts, or Copilot skills are added.
- Use `.doc-rules` as the source of truth for document structure and naming conventions.
