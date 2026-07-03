# EnterpriseRetailAI Documentation Repository

This repository contains the architecture documentation for the EnterpriseRetailAI platform, a globally distributed, AI-native retail Point-of-Sale solution built on TOGAF 10 ADM principles.

## What is included
- `EnterpriseRetailAI-Docs/` — core architecture documents (TOGAF, HLD, LLD, ADR, API specs, database schemas)
- `AGENTS.md` — navigation guide for AI agents and architecture questions
- `.doc-rules` — documentation validation rules and standards
- `validate-docs.sh` — local validation script for docs and schema artifacts
- `.github/workflows/validate-docs.yml` — GitHub Actions workflow for pull request validation
- `.copilot/skills/` — specialized AI guidance skills for documentation review
- `.copilot/prompts/` — templates for writing ADRs, HLDs, and LLDs
- `DOCUMENT_MANIFEST.md` — manifest of documentation artifacts, workflows, and skills

## Getting started
1. Read `GETTING_STARTED.md` for onboarding and contribution guidance.
2. Use `EnterpriseRetailAI-Docs/README.md` for the full architecture documentation index.
3. Follow `.doc-rules` when authoring or reviewing new documents.
4. Run `./validate-docs.sh --verbose` locally before opening a pull request.

## Validation workflow
This repository validates documentation on pull requests using the workflow in `.github/workflows/validate-docs.yml`. The workflow runs `validate-docs.sh` and posts validation results back to the PR.

## Authoring guidance
- Use `.copilot/prompts/new-adr-template.prompt.md` for new ADRs
- Use `.copilot/prompts/new-hld-template.prompt.md` for new HLDs
- Use `.copilot/prompts/new-lld-template.prompt.md` for new LLDs
- Refer to `AGENTS.md` for the right document to answer a question

## Reference files
- `GETTING_STARTED.md`
- `DOCUMENT_MANIFEST.md`
- `SKILL_EXAMPLES.md`
- `AGENTS.md`
- `.doc-rules`
- `.github/copilot-instructions.md`

---

*EnterpriseRetailAI Architecture Office*