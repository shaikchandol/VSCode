# SKILL_EXAMPLES.md

This file provides sample prompts and usage examples for the EnterpriseRetailAI Copilot skills.

## General Guidance
Use the `SKILL.md` files under `.copilot/skills/` to understand when each skill applies. These examples show how to frame questions for accurate, context-aware responses.

## Sample Prompts

### MLOps / Drift Monitoring
- "Explain the model retraining pipeline for demand forecasting in EnterpriseRetailAI."
- "What drift metrics does the system track for fraud detection models?"
- "How should a new Azure ML experiment be added to the MLOps pipeline?"

### Multitenancy Isolation
- "Describe the schema-per-tenant strategy for GDPR compliance."
- "How does tenant provisioning handle regional data residency requirements?"
- "What is the difference between tenant schema isolation and row-level security in this repo?"

### Offline-First Architecture
- "How does POS offline sync work when the store loses connectivity?"
- "Explain the CRDT conflict resolution process between POS and Store Edge."
- "What data is stored locally on the POS terminal versus the Store Edge?"

### Integration Architecture
- "Which API patterns should I use for integrating SAP with the store management platform?"
- "How are asynchronous events delivered in EnterpriseRetailAI?"
- "Describe the authentication model for external API consumers."

### Security & Compliance
- "What PCI-DSS controls are documented for payment processing?"
- "How does the system handle GDPR subject access requests?"
- "Which documents cover zero trust and audit logging?"

### Data Architecture
- "How is the tenant schema designed for transaction and inventory data?"
- "What replication strategy is used for multi-region data residency?"
- "Where are SQL DDL schemas stored and how are they versioned?"

### Performance & Scaling
- "What are the key scalability considerations for the store edge platform?"
- "How does EnterpriseRetailAI handle high transaction volume in the POS event log?"
- "Which documents explain capacity planning and performance tuning?"

## How to use these prompts
1. Select the skill most relevant to your question.
2. Use the sample prompt as a starting point.
3. Refer to the linked `SKILL.md` and repo docs for deeper detail.
