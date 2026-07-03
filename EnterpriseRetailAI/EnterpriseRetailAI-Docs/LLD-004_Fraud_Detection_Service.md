# LLD-004 — Fraud Detection Service
## EnterpriseRetailAI · Detailed Design: Feature Engineering, ONNX Pipeline, Ensemble Scoring

---

| Document ID | LLD-004 | Type | Low-Level Design | Version | 1.0 | Status | Approved |

---

## 1. Purpose

This document defines the low-level design of the Fraud Detection Service across all three inference tiers: POS device (ONNX LightGBM), Store Edge (ONNX Neural Network), and Cloud (Azure ML ensemble). It covers the feature engineering pipeline, model architectures, scoring logic, alert flow, and feedback loop for continuous learning.

---

## 2. Fraud Detection Architecture (3-Tier Ensemble)

```
┌──────────────────────────────────────────────────────────────────────┐
│                   FRAUD SCORING PIPELINE                            │
│                                                                      │
│  TIER 1: POS Device (< 50ms)                                        │
│  Features: 18 (transaction + card + device basics)                  │
│  Model: LightGBM → ONNX (quantised INT8, ~4MB)                      │
│  Action: Allow (< 0.4) | Step-up (0.4–0.7) | Decline (> 0.7)       │
│                                                                      │
│  TIER 2: Store Edge (< 200ms, called if Tier 1 score is 0.3–0.8)   │
│  Features: 25 (adds behavioural + shift context)                    │
│  Model: 3-layer neural net → ONNX (float32, ~8MB)                  │
│  Action: Refines Tier 1 score; triggers silent alert if needed      │
│                                                                      │
│  TIER 3: Cloud Batch (async, 1–5 min delay)                         │
│  Features: 35 (full feature vector + cross-store signals)           │
│  Model: Isolation Forest + Graph Neural Network (Azure ML)          │
│  Action: Retrospective detection; model feedback; pattern mining     │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Feature Vector Definition

### Tier 1 Features (POS — 18 features)

```python
TIER1_FEATURES = [
    # Transaction features
    "amount_gbp",               # transaction amount
    "line_count",               # number of distinct SKUs
    "quantity_total",           # total item count
    "discount_pct",             # total discount / subtotal
    "high_value_item_flag",     # any item > £200
    "cash_payment_flag",        # is payment method cash
    "split_tender_flag",        # split payment used
    "return_in_basket_flag",    # refund item in basket

    # Time features
    "hour_of_day",              # 0–23
    "day_of_week",              # 0–6
    "is_opening_hour",          # first 30 min after open
    "is_closing_hour",          # last 30 min before close

    # Card features (from P2PE metadata — no PAN)
    "card_bin_country_mismatch",# BIN country ≠ store country
    "card_type_encoded",        # 0=chip, 1=contactless, 2=QR
    "is_new_card_at_store",     # first use at this store

    # Device features
    "pos_error_rate_1h",        # recent scan errors
    "cashier_tx_count_1h",      # cashier velocity (1 hour)
    "offline_mode_flag",        # is POS in offline mode
]
```

### Additional Tier 2 Features (+7)

```python
TIER2_ADDITIONAL = [
    "customer_velocity_24h",    # transactions this customer (24h)
    "customer_return_rate_30d", # returns / purchases ratio
    "basket_category_entropy",  # diversity of product categories
    "promo_count",              # number of promotions applied
    "loyalty_redemption_flag",  # loyalty points redeemed
    "shift_tx_count",           # transactions in current shift
    "store_anomaly_score_1h",   # store-level anomaly from edge monitor
]
```

### Additional Tier 3 Features (+10)

```python
TIER3_ADDITIONAL = [
    "cross_store_customer_velocity",    # same customer other stores
    "card_cross_tenant_velocity",       # same BIN across tenants (anonymised)
    "graph_community_score",            # GNN: connected fraud community
    "time_since_last_fraud_alert",      # store-level fraud recency
    "product_fraud_risk_score",         # historical fraud rate for SKU
    "cashier_fraud_rate_30d",           # cashier historical rate
    "device_firmware_age_days",         # older firmware = higher risk
    "store_revenue_deviation",          # anomaly vs. expected revenue
    "promo_abuse_score",                # promo stacking pattern
    "network_connection_stability",     # % uptime (offline attempts)
]
```

---

## 4. LightGBM Training (Tier 1 Model)

```python
import lightgbm as lgb
from azureml.core import Run

def train_fraud_model(X_train, y_train, X_val, y_val, tenant_id: str):
    """
    Train per-tenant fraud detection model.
    y_train: binary (0=legitimate, 1=fraud)
    Class imbalance: typically 0.3% fraud rate
    """
    # Handle extreme class imbalance
    fraud_count = y_train.sum()
    legit_count = len(y_train) - fraud_count
    scale_pos_weight = legit_count / fraud_count  # ~333 for 0.3% fraud rate

    params = {
        "objective":         "binary",
        "metric":            ["binary_logloss", "auc"],
        "boosting_type":     "gbdt",
        "num_leaves":        63,
        "max_depth":         8,
        "learning_rate":     0.05,
        "n_estimators":      500,
        "scale_pos_weight":  scale_pos_weight,
        "min_child_samples": 20,
        "feature_fraction":  0.8,
        "bagging_fraction":  0.8,
        "bagging_freq":      5,
        "reg_alpha":         0.1,
        "reg_lambda":        0.2,
        "random_state":      42,
        "n_jobs":            -1,
    }

    model = lgb.LGBMClassifier(**params)
    model.fit(
        X_train, y_train,
        eval_set=[(X_val, y_val)],
        callbacks=[
            lgb.early_stopping(50),
            lgb.log_evaluation(50),
            lgb.record_evaluation(evals_result := {})
        ],
    )

    # Evaluate
    y_proba = model.predict_proba(X_val)[:, 1]
    metrics = evaluate_fraud_model(y_val, y_proba)

    # Gate: must meet KPI thresholds
    assert metrics["tpr_at_fpr_02"] >= 0.94, f"TPR {metrics['tpr_at_fpr_02']} below 0.94 threshold"
    assert metrics["fpr_at_tpr_94"] <= 0.02, f"FPR {metrics['fpr_at_tpr_94']} above 0.02 threshold"

    # Export to ONNX for POS deployment
    export_to_onnx(model, tenant_id, feature_names=TIER1_FEATURES)

    # Log to Azure ML
    run = Run.get_context()
    run.log("tenant_id", tenant_id)
    run.log("auc", metrics["auc"])
    run.log("tpr_at_fpr_02", metrics["tpr_at_fpr_02"])

    return model, metrics
```

---

## 5. ONNX Export & Quantisation

```python
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType
import onnx
from onnxruntime.quantization import quantize_dynamic, QuantType

def export_to_onnx(model, tenant_id: str, feature_names: list):
    # Convert LightGBM to ONNX
    initial_type = [("float_input", FloatTensorType([None, len(feature_names)]))]
    onnx_model = convert_sklearn(model, initial_types=initial_type,
                                 target_opset=17)

    # Validate ONNX model
    onnx.checker.check_model(onnx_model)

    raw_path = f"/tmp/fraud_detect_{tenant_id}_fp32.onnx"
    with open(raw_path, "wb") as f:
        f.write(onnx_model.SerializeToString())

    # Quantise to INT8 (4× smaller, ~2% accuracy impact)
    quantized_path = f"/tmp/fraud_detect_{tenant_id}_int8.onnx"
    quantize_dynamic(
        model_input=raw_path,
        model_output=quantized_path,
        weight_type=QuantType.QInt8,
    )

    # Compute SHA-256 hash for integrity verification
    import hashlib
    with open(quantized_path, "rb") as f:
        sha256 = hashlib.sha256(f.read()).hexdigest()

    return quantized_path, sha256
```

---

## 6. ONNX Inference (POS .NET 8)

```csharp
public class OnnxFraudScorer : IFraudScorer
{
    private readonly InferenceSession _session;
    private readonly FraudFeatureExtractor _extractor;

    public OnnxFraudScorer(string modelPath, byte[] expectedSha256)
    {
        // Verify model integrity before loading
        VerifyModelHash(modelPath, expectedSha256);

        var options = new SessionOptions();
        options.GraphOptimizationLevel = GraphOptimizationLevel.ORT_ENABLE_ALL;
        options.InterOpNumThreads = 1;   // single-threaded for POS
        options.IntraOpNumThreads = 2;
        _session = new InferenceSession(modelPath, options);
        _extractor = new FraudFeatureExtractor();
    }

    public FraudScore Score(TransactionContext context)
    {
        float[] features = _extractor.ExtractTier1(context);

        using var inputTensor = new DenseTensor<float>(features,
                                    new[] { 1, features.Length });
        var inputs = new List<NamedOnnxValue>
        {
            NamedOnnxValue.CreateFromTensor("float_input", inputTensor)
        };

        using var results = _session.Run(inputs);
        var probabilities = results
            .First(r => r.Name == "probabilities")
            .AsTensor<float>();

        float fraudProbability = probabilities[0, 1]; // P(fraud)

        return new FraudScore
        {
            Score     = fraudProbability,
            Decision  = ClassifyScore(fraudProbability),
            ModelVer  = _session.ModelMetadata.Version,
            InferenceMs = /* measured */ 0
        };
    }

    private static FraudDecision ClassifyScore(float score) => score switch
    {
        < 0.40f => FraudDecision.Allow,
        < 0.70f => FraudDecision.StepUpAuth,
        _       => FraudDecision.Decline
    };

    private static void VerifyModelHash(string path, byte[] expected)
    {
        using var sha256 = SHA256.Create();
        using var stream = File.OpenRead(path);
        byte[] actual = sha256.ComputeHash(stream);
        if (!actual.SequenceEqual(expected))
            throw new SecurityException("ONNX model hash mismatch — possible tampering");
    }
}
```

---

## 7. Tier 2 Neural Network (Store Edge)

```python
# PyTorch 3-layer classifier
class FraudNetEdge(nn.Module):
    def __init__(self, input_dim: int = 25):
        super().__init__()
        self.layers = nn.Sequential(
            nn.Linear(input_dim, 128),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            nn.Dropout(0.3),

            nn.Linear(128, 64),
            nn.BatchNorm1d(64),
            nn.ReLU(),
            nn.Dropout(0.2),

            nn.Linear(64, 32),
            nn.ReLU(),

            nn.Linear(32, 2),   # [P(legit), P(fraud)]
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return torch.softmax(self.layers(x), dim=1)

# Export for store edge: ONNX float32 (~8MB)
# Inference served by ONNX Runtime in IoT Edge fraud-detect-edge module
```

---

## 8. Fraud Alert Flow

```
Score ≥ 0.70 → DECLINE decision
    │
    ├─ POS: display declined message to cashier
    │       soft-alert sent to Store Edge (silent — cashier not shown reason)
    │
    ├─ Store Edge: fraud_alert event published to Kafka
    │   Payload:
    │   { "alert_id": uuid, "pos_id": str, "transaction_id": uuid,
    │     "score": 0.82, "tier": 1, "top_features": [...],
    │     "action": "DECLINE", "timestamp": ISO8601 }
    │
    ├─ Store Manager app: push notification (silent — do not embarrass customer)
    │   "Unusual transaction at POS-3 — monitor"
    │
    └─ Azure Event Hubs (on reconnect): fraud_alert event forwarded
       → Azure Sentinel: correlated with cross-tenant patterns
       → Azure ML: feedback label (confirmed fraud / false positive)
```

---

## 9. Model Feedback Loop

```
Fraud alerts → labelled outcomes (chargeback, confirmed, FP) → Azure Data Lake
    │
Weekly Azure ML pipeline:
  1. Load new labelled samples
  2. Append to training dataset (drift check first)
  3. Retrain if:
     a. New samples ≥ 1000 AND
     b. PSI (feature drift) > 0.20 for any key feature, OR
     c. TPR dropped > 5% on holdout
  4. Validate against holdout (tpr_at_fpr_02 ≥ 0.94)
  5. A/B test: 10% traffic → new model, 90% → old model (7 days)
  6. Auto-promote if new model wins on A/B; auto-rollback if not
  7. Export to ONNX → push to IoT Hub → POS devices updated
```

---

## 10. Bias Controls

```python
from fairlearn.metrics import MetricFrame, true_positive_rate, false_positive_rate

# Evaluate fairness across card type groups
metric_frame = MetricFrame(
    metrics={
        "TPR": true_positive_rate,
        "FPR": false_positive_rate,
    },
    y_true=y_test,
    y_pred=y_pred,
    sensitive_features=X_test["card_bin_country_mismatch"],  # proxy for origin
)

# Gate: max TPR difference across groups must be < 0.05
tpr_disparity = metric_frame.difference()["TPR"]
assert tpr_disparity < 0.05, f"TPR disparity {tpr_disparity} exceeds fairness threshold"
```

---

## 11. Performance & Reliability

| Metric | Target | Alert Threshold |
|---|---|---|
| Tier 1 inference latency (p99) | < 50ms | > 75ms |
| Tier 2 inference latency (p99) | < 200ms | > 300ms |
| Model load time at POS startup | < 2 seconds | > 5 seconds |
| True positive rate (holdout) | ≥ 94% | < 90% (auto-retrain) |
| False positive rate (holdout) | ≤ 2% | > 3% (auto-retrain) |
| Model file size (POS ONNX INT8) | < 20 MB | — |
| Feature extraction time | < 10ms | > 20ms |

---

## 12. Related Documents

| Document | Reference |
|---|---|
| AI/ML Platform HLD | `01_HLD/HLD-005_AI_ML_Platform.md` |
| MLOps Pipeline LLD | `02_LLD/LLD-015_MLOps_Pipeline_Design.md` |
| POS Transaction Engine LLD | `02_LLD/LLD-001_POS_Transaction_Engine.md` |
| Store Edge Orchestration LLD | `02_LLD/LLD-003_Store_Edge_Orchestration.md` |
