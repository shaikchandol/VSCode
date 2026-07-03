# LLD-008 — NLP Store Assistant
## EnterpriseRetailAI · RAG Architecture, Azure OpenAI, Phi-3 Offline, Intent Router

---

| Document ID | LLD-008 | Version | 1.0 | Status | Approved |

---

## 1. Architecture Overview

```
Input Channels
├── Touch kiosk (text input)
├── Voice (Whisper STT → text)
└── Staff mobile app (text)
        │
[Language Detection]
 Azure AI Translator — auto-detect, 40+ languages
        │
[Intent Classification]
 Ada-002 embeddings + cosine similarity to intent centroid vectors
 12 intent classes
        │
[RAG Retrieval]
 Azure AI Search (hybrid: semantic + keyword)
 Knowledge base: products, policies, FAQs, promotions
        │
[Response Generation]
 Online:  Azure OpenAI GPT-4o (cloud) → Azure AI Content Safety
 Offline: Phi-3-Mini-4K-Instruct (store edge, llama.cpp)
        │
Output
├── Text response (displayed)
├── Action card (product card, promotion card)
└── Voice (TTS — Azure Cognitive Services)
```

---

## 2. Intent Classification

```python
INTENT_CLASSES = [
    "product_search",      # "Where is the milk?"
    "price_enquiry",       # "How much is the red dress?"
    "stock_check",         # "Do you have size 12 in blue?"
    "return_policy",       # "How do I return something?"
    "store_hours",         # "What time do you close?"
    "promotion_info",      # "What offers do you have today?"
    "loyalty_balance",     # "How many points do I have?"
    "loyalty_redemption",  # "I want to use my points"
    "complaint",           # "I was overcharged"
    "staff_request",       # "Can I speak to a manager?"
    "product_info",        # "What allergens are in this?"
    "payment_help",        # "Do you accept Apple Pay?"
]

class IntentClassifier:
    def __init__(self, openai_client):
        self.client = openai_client
        # Pre-computed centroid embeddings for each intent class
        self.intent_centroids: dict[str, np.ndarray] = self._load_centroids()

    def classify(self, user_text: str, language: str = "en") -> IntentResult:
        # Embed the user query
        embedding_response = self.client.embeddings.create(
            model = "text-embedding-ada-002",
            input = user_text,
        )
        query_embedding = np.array(embedding_response.data[0].embedding)

        # Cosine similarity against intent centroids
        scores = {
            intent: cosine_similarity(query_embedding, centroid)
            for intent, centroid in self.intent_centroids.items()
        }

        best_intent = max(scores, key=scores.get)
        confidence  = scores[best_intent]

        # Low confidence → fallback to GPT classification
        if confidence < 0.72:
            best_intent = self._gpt_classify(user_text)
            confidence  = 0.0   # unknown (LLM fallback)

        return IntentResult(intent=best_intent, confidence=confidence,
                            all_scores=scores)
```

---

## 3. RAG Knowledge Base

```python
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizedQuery

class RetailKnowledgeBase:
    """
    Azure AI Search index with hybrid semantic + keyword retrieval.
    Per-tenant index: retailai-kb-{tenantId}
    """
    INDEX_SCHEMA = {
        "fields": [
            {"name": "doc_id",     "type": "Edm.String", "key": True},
            {"name": "content",    "type": "Edm.String", "searchable": True},
            {"name": "category",   "type": "Edm.String", "filterable": True},
            {"name": "store_id",   "type": "Edm.String", "filterable": True},
            {"name": "valid_until","type": "Edm.DateTimeOffset", "filterable": True},
            {"name": "embedding",  "type": "Collection(Edm.Single)",
             "dimensions": 1536, "vectorSearchProfile": "ada002-profile"},
        ],
        "vectorSearch": {
            "profiles": [{"name": "ada002-profile",
                          "algorithm": "hnsw", "metric": "cosine"}]
        },
        "semanticSearch": {
            "configurations": [{"name": "retail-semantic",
                                 "prioritizedFields": {"contentFields": [{"fieldName": "content"}]}}]
        }
    }

    def retrieve(
        self,
        query: str,
        query_embedding: list[float],
        intent: str,
        store_id: str,
        top_k: int = 5,
    ) -> list[Document]:

        vector_query = VectorizedQuery(
            vector  = query_embedding,
            fields  = "embedding",
            k_nearest_neighbors = top_k,
        )

        results = self.search_client.search(
            search_text   = query,
            vector_queries = [vector_query],
            filter        = (
                f"store_id eq '{store_id}' or store_id eq 'global' "
                f"and valid_until gt {datetime.utcnow().isoformat()}Z"
            ),
            query_type       = "semantic",
            semantic_configuration_name = "retail-semantic",
            top              = top_k,
            select           = ["doc_id", "content", "category"],
        )
        return [Document(r["doc_id"], r["content"], r["category"],
                         r["@search.score"])
                for r in results]
```

---

## 4. GPT-4o Response Generation

```python
from openai import AzureOpenAI

class StoreAssistantCloudEngine:
    SYSTEM_PROMPT_TEMPLATE = """
You are a helpful store assistant for {store_brand_name}.
You help customers with product questions, returns, loyalty, and store information.
Always be friendly, concise, and accurate.
Only answer questions about this store — redirect unrelated questions politely.
Language: respond in {language}.
Store name: {store_name}
Store hours today: {store_hours}
Current date and time: {datetime}
"""

    def generate(
        self,
        user_query: str,
        intent: str,
        retrieved_docs: list[Document],
        conversation_history: list[dict],
        store_context: StoreContext,
        language: str = "en",
    ) -> AssistantResponse:

        # Build context from retrieved documents
        context_text = "\n\n".join([
            f"[{doc.category.upper()}]\n{doc.content}"
            for doc in retrieved_docs
        ])

        system_prompt = self.SYSTEM_PROMPT_TEMPLATE.format(
            store_brand_name = store_context.brand_name,
            store_name       = store_context.store_name,
            store_hours      = store_context.today_hours,
            datetime         = datetime.now().strftime("%A %d %B %Y, %H:%M"),
            language         = language,
        )

        messages = [
            {"role": "system",    "content": system_prompt},
            {"role": "user",      "content": f"Store knowledge:\n{context_text}"},
        ]
        # Append recent conversation history (last 5 turns)
        messages.extend(conversation_history[-10:])
        messages.append({"role": "user", "content": user_query})

        response = self.client.chat.completions.create(
            model       = "gpt-4o",
            messages    = messages,
            max_tokens  = 300,
            temperature = 0.3,    # low temperature for factual accuracy
            stream      = True,
        )

        full_text = ""
        for chunk in response:
            if chunk.choices[0].delta.content:
                full_text += chunk.choices[0].delta.content
                yield chunk.choices[0].delta.content  # stream to UI

        # Content safety filter (post-generation)
        safety_result = self.content_safety.analyze(full_text)
        if safety_result.is_unsafe:
            yield "[FILTERED]"  # replace unsafe content
            full_text = self.SAFE_FALLBACK_RESPONSE

        return AssistantResponse(text=full_text, model="gpt-4o",
                                 retrieved_docs=[d.doc_id for d in retrieved_docs])
```

---

## 5. Phi-3 Offline Engine (Store Edge)

```python
# llama.cpp Python bindings — runs Phi-3-Mini-4K-Instruct.Q4_K_M.gguf
from llama_cpp import Llama

class StoreAssistantOfflineEngine:
    """
    Offline NLP using Phi-3 Mini on store edge.
    Reduced capability: product search + FAQ + store info only.
    Model: Phi-3-Mini-4K-Instruct (Q4_K_M GGUF, ~2.4GB, 3GB RAM)
    """
    OFFLINE_SYSTEM_PROMPT = """You are a store assistant. Answer briefly based only on:
Store: {store_name} | Hours: {hours}
Available knowledge:
{knowledge}
Language: {language}. Be concise (under 100 words)."""

    def __init__(self, model_path: str = "/models/phi3-mini-q4.gguf"):
        self.llm = Llama(
            model_path  = model_path,
            n_ctx       = 4096,
            n_threads   = 4,
            n_gpu_layers = 0,     # CPU-only on standard edge hardware
            verbose     = False,
        )

    def generate(
        self,
        user_query: str,
        local_knowledge: list[str],
        store_context: StoreContext,
        language: str = "en",
    ) -> str:

        knowledge = "\n".join(f"- {k}" for k in local_knowledge[:5])
        system = self.OFFLINE_SYSTEM_PROMPT.format(
            store_name = store_context.store_name,
            hours      = store_context.today_hours,
            knowledge  = knowledge,
            language   = language,
        )

        output = self.llm.create_chat_completion(
            messages = [
                {"role": "system",  "content": system},
                {"role": "user",    "content": user_query},
            ],
            max_tokens  = 150,
            temperature = 0.2,
            stop        = ["\n\n", "Customer:"],
        )
        return output["choices"][0]["message"]["content"].strip()
```

---

## 6. Voice Input (Whisper STT)

```python
import openai

class VoiceInputHandler:
    def transcribe_online(self, audio_bytes: bytes, language_hint: str = "en") -> str:
        # Cloud: OpenAI Whisper API (< 500ms for < 30s audio)
        response = self.openai_client.audio.transcriptions.create(
            model    = "whisper-1",
            file     = ("audio.webm", audio_bytes, "audio/webm"),
            language = language_hint,
        )
        return response.text

    def transcribe_offline(self, audio_bytes: bytes) -> str:
        # Store Edge: Whisper-tiny ONNX (fast, lower accuracy)
        # Loaded as IoT Edge module: whisper-tiny-edge
        result = self.edge_whisper_client.transcribe(audio_bytes)
        return result["text"]
```

---

## 7. Knowledge Base Sync (Offline Cache)

```
Every 15 minutes (online mode):
  Store Edge pulls from Azure AI Search:
  - Updated products (last 15min)
  - Active promotions
  - Policy changes

Stored locally:
  /var/retailai/kb_cache/
  ├── products.jsonl       (full catalogue, updated daily)
  ├── promotions.jsonl     (active only, TTL-based)
  ├── policies.jsonl       (store + return + loyalty)
  └── faqs.jsonl           (500 most common Q&As)

Offline retrieval: BM25 full-text search on local JSONL files
  Library: rank-bm25 (Python) in nlp-phi3-assistant IoT Edge module
```

---

## 8. Content Safety

```python
from azure.ai.contentsafety import ContentSafetyClient
from azure.ai.contentsafety.models import AnalyzeTextOptions, TextCategory

def filter_response(text: str) -> tuple[str, bool]:
    """
    Returns (safe_text, was_filtered).
    Applied to all GPT-4o responses before display.
    """
    result = safety_client.analyze_text(
        AnalyzeTextOptions(
            text       = text,
            categories = [TextCategory.HATE, TextCategory.VIOLENCE,
                          TextCategory.SEXUAL, TextCategory.SELF_HARM],
        )
    )

    for item in result.categories_analysis:
        if item.severity >= 2:   # 0=safe, 2=low, 4=medium, 6=high
            return SAFE_FALLBACK, True

    return text, False

SAFE_FALLBACK = "I'm sorry, I can't help with that. Please ask a staff member."
```

---

## 9. Conversation State Management

```python
# Stored in Redis (online) or in-memory dict (offline)
# Key: session_id (UUID, TTL: 30 minutes)

@dataclass
class ConversationSession:
    session_id:   str
    customer_id:  str | None     # None if anonymous
    store_id:     str
    language:     str
    started_at:   datetime
    history:      list[dict]     # [{"role":"user","content":...}, ...]
    intent_log:   list[str]      # sequence of detected intents
    last_activity: datetime
```

---

## 10. Performance Targets

| Metric | Online (Cloud) | Offline (Phi-3 Edge) |
|---|---|---|
| Intent classification latency | < 200ms | < 100ms (local cosine) |
| RAG retrieval latency | < 300ms | < 50ms (local BM25) |
| GPT-4o first token latency | < 800ms | N/A |
| Phi-3 Mini first token | N/A | < 2000ms |
| Full response (200 tokens) | < 3 seconds | < 8 seconds |
| Intent accuracy | > 92% | > 80% (reduced classes offline) |

---

## 11. Related Documents

- HLD-005: AI/ML Platform
- LLD-003: Store Edge Orchestration
- LLD-014: API Design
