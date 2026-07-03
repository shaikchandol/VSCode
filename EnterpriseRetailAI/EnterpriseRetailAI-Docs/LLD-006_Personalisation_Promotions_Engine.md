# LLD-006 — Personalisation & Promotions Engine
## EnterpriseRetailAI · Collaborative Filtering, Contextual Bandits, Promo Resolver

---

| Document ID | LLD-006 | Version | 1.0 | Status | Approved |

---

## 1. Architecture Overview

```
Customer Identified (loyalty card / QR)
        │
[Customer Embedding Service]
 Azure AI Search — vector store
 Customer embedding = avg(purchase_embeddings) + category_affinity_vec
        │
[Recommendation Engine — AKS]
 Phase 1: Candidate generation (top-50 via ANN search)
 Phase 2: Feature enrichment (basket context + stock + weather)
 Phase 3: Contextual Bandit re-ranking (explore/exploit)
        │
[Promotion Resolver]
 HQ rules + Franchisee overrides + AI scores
 Conflict resolution: mutually exclusive promos filtered
        │
[POS Promo Display]
 Top 3 shown on cashier screen + customer-facing display
        │
[Outcome Capture]
 Accepted / declined / modified → reward signal → bandit update
```

---

## 2. Customer Embedding

```python
from sentence_transformers import SentenceTransformer
import numpy as np

class CustomerEmbeddingService:
    """
    Generates a 384-dim customer embedding from purchase history.
    Used for ANN retrieval against product/promo embeddings.
    """
    def __init__(self):
        # all-MiniLM-L6-v2 — 384 dims, fast, good quality
        self.model = SentenceTransformer("all-MiniLM-L6-v2")

    def build_embedding(self, purchase_history: list[dict]) -> np.ndarray:
        if not purchase_history:
            return np.zeros(384)

        # Build customer "document" from purchase history
        # Weight recent purchases higher (exponential decay)
        texts = []
        for tx in purchase_history[-90:]:  # last 90 days
            category  = tx.get("category", "")
            brand     = tx.get("brand", "")
            sku_name  = tx.get("product_name", "")
            texts.append(f"{category} {brand} {sku_name}")

        # Encode and average with recency weighting
        embeddings = self.model.encode(texts, normalize_embeddings=True)
        weights    = np.exp(np.linspace(-1, 0, len(texts)))  # recency decay
        weights   /= weights.sum()
        return np.average(embeddings, axis=0, weights=weights)
```

---

## 3. Matrix Factorisation (Collaborative Filtering)

```python
import implicit  # ALS-based collaborative filtering

class CollaborativeFilteringModel:
    """
    Item-based collaborative filtering using ALS (Alternating Least Squares).
    Trained per franchisee on purchase history.
    """
    def __init__(self, factors: int = 128, iterations: int = 20):
        self.model = implicit.als.AlternatingLeastSquares(
            factors    = factors,
            iterations = iterations,
            regularization = 0.01,
            use_gpu    = False,
        )
        self.customer_id_map: dict = {}
        self.promo_id_map: dict    = {}

    def train(self, interactions_df):
        """
        interactions_df: customer_id, promo_id, interaction_weight
        interaction_weight: 1=viewed, 3=clicked, 10=redeemed, -1=declined
        """
        from scipy.sparse import csr_matrix
        matrix = csr_matrix(
            (interactions_df["weight"],
             (interactions_df["customer_idx"],
              interactions_df["promo_idx"]))
        )
        self.model.fit(matrix)

    def recommend(self, customer_id: str, n: int = 50) -> list[tuple[str, float]]:
        customer_idx = self.customer_id_map.get(customer_id)
        if customer_idx is None:
            return []  # cold start — fall back to popularity baseline
        items, scores = self.model.recommend(
            customer_idx,
            self.interaction_matrix[customer_idx],
            N = n,
            filter_already_liked_items = False,
        )
        return [(self.promo_id_reverse[i], float(s)) for i, s in zip(items, scores)]
```

---

## 4. Contextual Bandit Re-Ranking (Vowpal Wabbit)

```python
import vowpalwabbit as vw

class ContextualBanditRanker:
    """
    VW CB Explore ADF (Action-Dependent Features) bandit.
    Learns which promotions work best given basket context.
    Balances exploration (new promos) vs exploitation (known winners).
    """
    def __init__(self, epsilon: float = 0.05):
        self.vw = vw.Workspace(
            f"--cb_explore_adf --epsilon {epsilon} "
            "--l1 0.001 --l2 0.001 "
            "--quiet"
        )

    def rank(
        self,
        context: dict,           # basket features, time, weather, etc.
        candidate_promos: list,  # from collaborative filtering
    ) -> list[tuple[str, float]]:  # (promo_id, score)

        # Build VW example string
        context_str = self._encode_context(context)
        actions_str = "\n".join([
            f"{i}:{self._encode_promo(p)}"
            for i, p in enumerate(candidate_promos)
        ])
        vw_input = f"shared |Context {context_str}\n{actions_str}"

        pred = self.vw.predict(vw_input)
        return [(candidate_promos[i]["promo_id"], score)
                for i, (_, score) in enumerate(pred)]

    def update(
        self,
        context: dict,
        chosen_promo_idx: int,
        reward: float,           # 1.0=redeemed, 0.0=declined, 0.5=viewed
        probability: float,
    ):
        """Online update after observing reward."""
        context_str = self._encode_context(context)
        cost = -reward           # VW minimises cost
        vw_example = (
            f"shared |Context {context_str}\n"
            f"{chosen_promo_idx}:{cost}:{probability} |Action ..."
        )
        self.vw.learn(vw_example)

    def _encode_context(self, ctx: dict) -> str:
        return (
            f"hour={ctx['hour_of_day']} dow={ctx['day_of_week']} "
            f"basket_total={int(ctx['basket_total_gbp'])} "
            f"category_count={ctx['category_count']} "
            f"weather={ctx.get('weather_code', 'unknown')} "
            f"is_loyalty={int(ctx['is_loyalty_member'])}"
        )
```

---

## 5. Promotion Resolver

```python
from dataclasses import dataclass

@dataclass
class ResolvedPromotion:
    promo_id:        str
    name:            str
    discount_type:   str     # "pct", "fixed", "bogo", "bundle"
    discount_value:  float
    ai_score:        float
    reason:          str     # shown to customer

class PromotionResolver:
    """
    Applies business rules to filter and de-conflict AI-ranked promos.
    """
    MAX_PROMOS_APPLIED = 3
    MAX_DISCOUNT_PCT_TOTAL = 40.0  # safety cap: max 40% off any basket

    def resolve(
        self,
        ranked_promos: list[tuple[str, float]],
        basket: Basket,
        tenant_rules: TenantPromoRules,
    ) -> list[ResolvedPromotion]:

        resolved = []
        applied_groups = set()   # mutually exclusive groups
        total_discount_pct = 0.0

        for promo_id, score in ranked_promos:
            promo = self.promo_repo.get(promo_id)
            if promo is None:
                continue

            # Rule 1: Promo valid for basket contents?
            if not promo.is_applicable(basket):
                continue

            # Rule 2: Mutually exclusive group check
            if promo.exclusive_group in applied_groups:
                continue

            # Rule 3: Total discount safety cap
            estimated_discount_pct = promo.estimate_discount_pct(basket)
            if total_discount_pct + estimated_discount_pct > self.MAX_DISCOUNT_PCT_TOTAL:
                continue

            # Rule 4: Franchisee budget remaining for this promotion
            if tenant_rules.is_budget_exhausted(promo_id):
                continue

            resolved.append(ResolvedPromotion(
                promo_id      = promo_id,
                name          = promo.display_name,
                discount_type = promo.discount_type,
                discount_value= promo.value,
                ai_score      = score,
                reason        = promo.customer_reason,
            ))
            applied_groups.add(promo.exclusive_group)
            total_discount_pct += estimated_discount_pct

            if len(resolved) >= self.MAX_PROMOS_APPLIED:
                break

        return resolved
```

---

## 6. GDPR Consent Flow

```python
class PersonalisationConsentMiddleware:
    """
    Checks and enforces GDPR/CCPA consent before personalisation.
    Falls back to anonymous segment-based promos if no consent.
    """
    def get_customer_context(
        self,
        loyalty_id: str,
        purposes: list[str] = ["personalised_promotions"],
    ) -> CustomerContext:

        consent = self.consent_repo.get(loyalty_id)

        if consent is None or not consent.has_all(purposes):
            # No personal data used — segment-based fallback only
            return CustomerContext(
                customer_id      = None,
                segment          = self.segmenter.get_anonymous_segment(),
                is_personalised  = False,
                consent_purposes = [],
            )

        return CustomerContext(
            customer_id      = loyalty_id,
            segment          = consent.segment,
            purchase_history = self.history_repo.get(loyalty_id),
            is_personalised  = True,
            consent_purposes = consent.purposes,
        )
```

---

## 7. A/B Test Framework

```yaml
# Feature flag config (Azure App Configuration)
personalisation_ab_test:
  enabled: true
  variants:
    control:
      weight: 50
      strategy: "rule_based_only"
    treatment:
      weight: 50
      strategy: "ai_personalised"
  metrics:
    primary: "basket_value_gbp"
    secondary: ["promo_redemption_rate", "items_per_transaction"]
  min_sample_size: 1000   # per variant before decision
  significance_level: 0.05
```

---

## 8. API Contract

```
POST /api/v1/promotions/rank
Headers: Authorization, X-Tenant-ID, X-Store-ID
Request:
{
  "basket": {
    "lines": [{"sku_id": "...", "quantity": 2, "amount_gbp": 15.99}],
    "total_gbp": 47.50,
    "is_loyalty_member": true,
    "loyalty_id": "CUST-12345"
  },
  "pos_context": {
    "hour_of_day": 14, "day_of_week": 3,
    "weather_code": "sunny", "pos_mode": "online"
  }
}

Response 200:
{
  "ranked_promotions": [
    {
      "promo_id": "promo_042",
      "name": "20% off your 3rd visit",
      "discount_type": "pct",
      "discount_value": 20.0,
      "estimated_saving_gbp": 9.50,
      "ai_score": 0.87,
      "reason": "Welcome back! Here's your loyalty reward."
    }
  ],
  "is_personalised": true,
  "model_version": "bandit_v1.8.0",
  "latency_ms": 84
}
```

---

## 9. Related Documents

- HLD-005: AI/ML Platform
- LLD-001: POS Transaction Engine (promo application)
- LLD-014: API Design
