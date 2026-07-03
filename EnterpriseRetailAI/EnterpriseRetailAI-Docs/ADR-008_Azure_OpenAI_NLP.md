# ADR-008 — Azure OpenAI GPT-4o + RAG for NLP Store Assistant
## EnterpriseRetailAI · Architecture Decision Record

| ID | ADR-008 | Status | Approved |

---

## Context

The NLP Store Assistant must answer customer and staff queries about products, promotions, stock, returns, and store policies in 40+ languages with < 3 second response time. Three approaches were evaluated.

---

## Options Considered

### Option A: Fine-tuned proprietary model
- Maximum domain accuracy
- Fine-tuning cost: ~$50,000 per franchisee per language × 40 languages = prohibitive
- Retraining required every time catalogue or policies change
- Offline fallback impossible

### Option B: Azure OpenAI GPT-4o + RAG ✅ (Selected)
- Zero training cost — RAG retrieval from Azure AI Search
- Knowledge base updates in minutes (re-index changed documents)
- GDPR-compliant: Azure OpenAI with no-training data agreement
- Offline: Phi-3-Mini SLM (2.4GB GGUF) on store edge — reduced capability

### Option C: Open-source LLM (Llama-3, Mistral) self-hosted
- No API cost — compute cost instead
- GPU required at store edge for acceptable latency
- No Azure AI Content Safety integration
- GDPR: self-hosted data processing is compliant but increases infra complexity

---

## Decision

**Azure OpenAI GPT-4o + RAG (Azure AI Search)** for online mode.
**Phi-3-Mini-4K-Instruct** (GGUF, llama.cpp) for offline store edge mode.

---

## Consequences

**Positive:**
- Knowledge base updates propagate in minutes — no retraining cycle
- 40+ languages via Azure AI Translator — single model, all markets
- Azure AI Content Safety guardrails prevent harmful/off-topic responses
- Offline mode via Phi-3 Mini covers product search + FAQ (90% of queries)

**Negative:**
- GPT-4o token cost scales with query volume — budget capped per tenant
- Phi-3 offline limited to English + top-5 languages; 40+ only online
- Azure OpenAI availability (99.9% SLA) adds cloud dependency for full NLP

**Cost Control:** Per-tenant token quota enforced at APIM layer. Monthly budget alerts via Azure Cost Management.

**GDPR Compliance:** Azure OpenAI "no-train" data agreement in place. Customer queries never used for model training.

