# Model Cards
## EnterpriseRetailAI · Model Cards for All 6 AI Use Cases

---

| Document | Model_Cards | Version | 1.0 | Status | Approved |

---

## Overview

Model cards are published for all production AI models in compliance with:
- **GDPR Article 13/14** — transparency in automated decision-making
- **EU AI Act** — high-risk AI system documentation requirements
- **Internal AI Governance Policy** — CDO sign-off required before production deployment

Each model card is stored in Azure ML Model Registry as a JSON artifact (`model_card` tag) and published to the franchisee admin portal.

---

## Model Card 1 — Demand Forecasting (UC1)

```json
{
  "model_name": "demand-forecast-{tenant_id}",
  "version": "tft_v3.1.0",
  "last_updated": "2026-06-01",
  "approved_by": "Chief Data Officer",

  "model_details": {
    "description": "Temporal Fusion Transformer (TFT) that predicts daily unit sales at SKU-store level for 7, 14, and 30-day horizons. Produces P10, P50, P90 quantile forecasts to support replenishment planning.",
    "type": "Time-series forecasting (quantile regression)",
    "framework": "PyTorch + PyTorch Forecasting",
    "architecture": "Temporal Fusion Transformer with LSTM encoder, multi-head attention, and variable selection networks",
    "input_features": [
      "Daily sales history (90-day lookback per SKU per store)",
      "Day of week, week of year, month, holiday flags",
      "Promotion active flag (from promotional calendar)",
      "Weather (temperature, precipitation)",
      "Product category, price tier, seasonality flag"
    ],
    "output": "P10, P50, P90 unit sales forecast for 7/14/30-day horizons"
  },

  "intended_use": {
    "primary_use": "Automated replenishment suggestions for store managers",
    "in_scope": [
      "SKU-level store replenishment",
      "Supplier purchase order generation",
      "Safety stock level recommendations"
    ],
    "out_of_scope": [
      "Financial revenue forecasting",
      "New product forecasting (< 30 days sales history)",
      "Promotional effectiveness modelling"
    ]
  },

  "performance": {
    "primary_metric": "MAPE (Mean Absolute Percentage Error) on 30-day holdout",
    "production_kpi": "MAPE < 12%",
    "latest_evaluation": {
      "mape_7d": 7.4,
      "mape_14d": 9.1,
      "mape_30d": 11.3,
      "p90_coverage": 0.912,
      "bias": -0.024,
      "evaluation_date": "2026-06-01",
      "evaluation_dataset_size": 450000
    }
  },

  "training_data": {
    "description": "2 years of daily sales transactions per SKU per store",
    "data_sources": ["POS transaction events (Event Hubs → ADLS Gen2)"],
    "data_period": "2024-01-01 to 2026-05-31",
    "preprocessing": "Synapse Spark aggregation pipeline; outlier capping at P99; zero-sales day handling",
    "data_lineage": "Azure Purview: retailai-lineage/demand-forecast/{tenant_id}"
  },

  "fairness_and_bias": {
    "protected_attributes": "None applicable (product-level forecast, no customer data)",
    "bias_evaluation": "N/A — no demographic data used",
    "known_limitations": [
      "Performance degrades for SKUs with < 30 days history (cold start)",
      "Seasonal events not in training calendar may cause spikes",
      "Accuracy lower for high-variance products (promotions, weather-sensitive)"
    ]
  },

  "explainability": {
    "method": "Built-in TFT variable importance scores",
    "explanation_recipients": "Store managers (via replenishment dashboard)",
    "example_explanation": "Rolling 14-day average (28%), day of week (19%), promotion active (14%)"
  },

  "human_oversight": {
    "automated_actions": "Purchase order suggestion only — no autonomous ordering",
    "human_approval": "Store manager approves all POs before submission to ERP",
    "override_mechanism": "Manager can reject or modify any suggested quantity"
  },

  "monitoring": {
    "drift_monitoring": "Evidently AI — daily PSI check on feature distributions",
    "performance_monitoring": "Azure ML Monitor — weekly MAPE on actuals vs. forecast",
    "retrain_trigger": "PSI > 0.20 on any key feature OR MAPE > 14% on rolling 7-day window",
    "retrain_frequency": "Daily incremental; full retrain weekly"
  },

  "contact": {
    "model_owner": "CDO — AI Platform Team",
    "escalation": "ai-platform@retailai.com",
    "incident_process": "ServiceNow — AI Incident category"
  }
}
```

---

## Model Card 2 — Fraud Detection (UC2)

```json
{
  "model_name": "fraud-detection-{tenant_id}",
  "version": "fraud-detect-v2.4.1",
  "last_updated": "2026-06-01",
  "approved_by": "Chief Data Officer + CISO",

  "model_details": {
    "description": "Three-tier fraud detection ensemble: LightGBM at POS (< 50ms), neural network at store edge (< 200ms), Graph Neural Network batch in cloud. Scores transactions 0.0–1.0 with Allow/Step-Up/Decline decisions.",
    "type": "Binary classification (fraud vs. legitimate)",
    "architecture": {
      "tier1_pos": "LightGBM → ONNX INT8 (18 features, 4MB)",
      "tier2_edge": "3-layer MLP → ONNX FP32 (25 features, 8MB)",
      "tier3_cloud": "Isolation Forest + Graph Neural Network (35 features)"
    },
    "class_imbalance": "~0.3% fraud rate — handled via scale_pos_weight ≈ 333"
  },

  "intended_use": {
    "primary_use": "Real-time fraud scoring at point of sale for transaction Allow/Step-Up/Decline decisions",
    "in_scope": ["Card-present transactions", "Contactless NFC transactions", "Offline tokenised payments"],
    "out_of_scope": ["Card-not-present e-commerce", "Account takeover detection", "First-party fraud"]
  },

  "performance": {
    "primary_metrics": "TPR at 2% FPR ≥ 94%; FPR at 94% TPR ≤ 2%",
    "latest_evaluation": {
      "auc_roc": 0.984,
      "tpr_at_fpr_02": 0.961,
      "fpr_at_tpr_94": 0.018,
      "precision_at_threshold_07": 0.87,
      "evaluation_date": "2026-06-01",
      "evaluation_dataset_size": 2800000,
      "fraud_samples_in_test": 8400
    }
  },

  "training_data": {
    "description": "90 days of transaction events with confirmed fraud labels (chargebacks + manual review)",
    "label_sources": ["Chargeback notifications (Adyen/Stripe)", "Store manager confirmed fraud flags"],
    "data_period": "Rolling 90-day window, updated weekly",
    "data_lineage": "Azure Purview: retailai-lineage/fraud-detection/{tenant_id}"
  },

  "fairness_and_bias": {
    "protected_attributes_monitored": ["card_bin_country_mismatch (proxy for cardholder origin)", "card_type_encoded"],
    "bias_metric": "Equalized Odds — max TPR disparity across groups < 5%",
    "latest_bias_check": {
      "max_tpr_disparity": 0.032,
      "max_fpr_disparity": 0.019,
      "passed": true,
      "evaluation_date": "2026-06-01"
    },
    "known_limitations": [
      "Reduced accuracy for international cards not seen in training data",
      "Offline mode uses 18-feature model with ~3% lower TPR",
      "Cold-start tenants use HQ baseline model until 1000 fraud samples collected"
    ]
  },

  "explainability": {
    "method": "SHAP top-3 feature contributions per declined transaction",
    "explanation_recipients": "Store managers (via alert notification) + audit log",
    "gdpr_art22_compliance": "Human override available at POS for all Decline decisions — manager can approve transaction",
    "example_explanation": "Declined: high amount (0.42) + BIN country mismatch (0.31) + new card (0.18)"
  },

  "human_oversight": {
    "allow": "Fully automated — no human review",
    "step_up": "Manager PIN approval required before transaction proceeds",
    "decline": "Manager can override decline and approve transaction with authorisation code",
    "audit": "All decisions (Allow/Step-Up/Decline) logged to immutable audit trail"
  },

  "monitoring": {
    "drift_monitoring": "Evidently AI — daily PSI on all 18 Tier-1 features",
    "performance_monitoring": "Weekly holdout evaluation — auto-retrain if TPR < 90%",
    "retrain_trigger": "PSI > 0.20 on key features OR TPR drops > 5% vs. baseline",
    "feedback_loop": "Chargeback labels ingested weekly; false positive flags from managers"
  },

  "contact": {
    "model_owner": "CDO — AI Platform Team",
    "regulatory_contact": "CISO for PCI-DSS queries; DPO for GDPR Art 22 queries"
  }
}
```

---

## Model Card 3 — Personalised Promotions (UC3)

```json
{
  "model_name": "promotion-ranker-{tenant_id}",
  "version": "bandit_v1.8.0",
  "last_updated": "2026-06-01",
  "approved_by": "Chief Data Officer",

  "model_details": {
    "description": "Two-stage personalisation: Collaborative Filtering (ALS) for candidate generation + Vowpal Wabbit Contextual Bandit for real-time ranking. Selects top-3 promotions for each basket.",
    "type": "Recommendation system (collaborative filtering + contextual bandits)",
    "consent_required": "GDPR/CCPA explicit opt-in for personalised_promotions purpose"
  },

  "intended_use": {
    "primary_use": "Rank and present personalised promotions at POS for loyalty members",
    "fallback_without_consent": "Anonymous segment-based promotions (no individual tracking)",
    "in_scope": ["Loyalty programme members with consent", "In-store POS transactions"],
    "out_of_scope": ["Non-loyalty customers", "Online/e-commerce channel", "Email marketing"]
  },

  "performance": {
    "primary_metric": "Basket value lift vs. rule-based control (A/B test)",
    "latest_evaluation": {
      "basket_lift_pct": 11.2,
      "promo_redemption_rate": 0.34,
      "control_redemption_rate": 0.21,
      "ab_test_duration_days": 30,
      "ab_test_significance": 0.001,
      "evaluation_date": "2026-06-01"
    }
  },

  "training_data": {
    "description": "90 days of customer-promotion interactions for loyalty members with consent",
    "interaction_types": "Viewed (weight=1), Clicked (weight=3), Redeemed (weight=10), Declined (weight=-1)",
    "pii_handling": "Customer embeddings computed from purchase history; raw PII never in training pipeline",
    "data_lineage": "Azure Purview: retailai-lineage/personalisation/{tenant_id}"
  },

  "fairness_and_bias": {
    "protected_attributes_monitored": ["Age group (derived from date_of_birth)", "Gender (if provided)"],
    "bias_metric": "Demographic parity — offer rates should not differ > 10% across groups",
    "known_limitations": [
      "Cold-start: new customers with < 3 transactions receive popularity-based promos",
      "Consent withdrawal: customer immediately falls back to anonymous segment promos"
    ]
  },

  "explainability": {
    "method": "LIME — promotion reason shown to customer on POS screen",
    "example": "'Your weekly dairy shop — save 20% today!'"
  },

  "human_oversight": {
    "override": "Cashier can manually apply any eligible promotion overriding AI rank",
    "budget_cap": "Franchisee sets promotion budget; system enforces hard cap"
  },

  "gdpr_controls": {
    "lawful_basis": "Consent (Art. 6(1)(a))",
    "consent_granularity": "Per-purpose: personalised_promotions",
    "erasure": "Embeddings deleted within 24h of erasure request; history purged from feature store"
  }
}
```

---

## Model Card 4 — Computer Vision Self-Checkout (UC4)

```json
{
  "model_name": "cv-item-recognition-{tenant_id}",
  "version": "yolov8n_v1.8.0",
  "last_updated": "2026-06-01",
  "approved_by": "Chief Data Officer",

  "model_details": {
    "description": "YOLOv8n fine-tuned per franchisee on SKU images for self-checkout item recognition. Confidence ≥ 0.92 auto-adds to basket; 0.70–0.92 requests re-present; < 0.70 calls attendant.",
    "type": "Object detection (multi-class)",
    "base_model": "YOLOv8n pre-trained on COCO (Ultralytics)",
    "deployment": "Store edge IoT Edge module (ONNX INT8)"
  },

  "intended_use": {
    "primary_use": "Automated item recognition at self-checkout kiosk when barcode is unreadable",
    "fallback": "Barcode scanner is primary; CV is fallback only",
    "in_scope": ["Self-checkout kiosks with camera arrays", "Items in HQ/franchisee product catalogue"],
    "out_of_scope": ["Facial recognition", "Customer identification", "Surveillance"]
  },

  "performance": {
    "primary_metric": "mAP50 ≥ 98.5% on per-tenant held-out test set",
    "latest_evaluation": {
      "map50": 0.991,
      "map50_95": 0.874,
      "precision": 0.983,
      "recall": 0.978,
      "false_accept_rate": 0.0008,
      "evaluation_date": "2026-06-01"
    }
  },

  "fairness_and_bias": {
    "known_bias_risks": ["Lighting variation (corrected with HSV augmentation)", "Packaging variant bias (mitigated with diverse training images)"],
    "bias_mitigation": "Training images collected under varied lighting, angles, and packaging variants; minimum 200 images per SKU"
  },

  "privacy": {
    "camera_data": "Camera frames processed locally on store edge — never sent to cloud",
    "retention": "No frames retained after inference; inference result only (SKU ID + confidence)",
    "gdpr": "No personal data processed — item recognition only, no biometrics"
  },

  "human_oversight": {
    "low_confidence": "Attendant called for confidence < 0.70",
    "weight_mismatch": "Attendant called for weight deviation > 5%",
    "anti_theft": "Unscanned item detection freezes kiosk and alerts attendant"
  }
}
```

---

## Model Card 5 — NLP Store Assistant (UC5)

```json
{
  "model_name": "nlp-store-assistant",
  "version": "gpt-4o-2026-05 + phi3-mini-4k-q4",
  "last_updated": "2026-06-01",
  "approved_by": "Chief Data Officer",

  "model_details": {
    "description": "RAG-based store assistant powered by Azure OpenAI GPT-4o (online) and Phi-3-Mini-4K (offline). Answers product, promotion, stock, and store policy queries in 40+ languages.",
    "online_model": "Azure OpenAI GPT-4o via Azure OpenAI Service",
    "offline_model": "Phi-3-Mini-4K-Instruct GGUF Q4_K_M (llama.cpp, store edge)",
    "retrieval": "Azure AI Search (hybrid semantic + keyword) — knowledge base per tenant"
  },

  "intended_use": {
    "primary_use": "Answer customer and staff queries about products, promotions, and store policies",
    "in_scope": ["Product location queries", "Price and stock enquiries", "Return policy questions", "Loyalty balance checks", "Promotion information"],
    "out_of_scope": ["Medical or legal advice", "Personal financial advice", "Competitor comparisons", "Off-topic general conversation"]
  },

  "performance": {
    "primary_metric": "Intent classification accuracy > 92% (online), > 80% (offline)",
    "latest_evaluation": {
      "intent_accuracy_online": 0.943,
      "intent_accuracy_offline": 0.821,
      "response_factual_accuracy": 0.967,
      "user_satisfaction_rating": 4.2,
      "evaluation_date": "2026-06-01"
    }
  },

  "safety_guardrails": {
    "content_safety": "Azure AI Content Safety — all responses filtered before display",
    "severity_threshold": "Any category severity ≥ 2 (low) triggers safe fallback response",
    "topic_restrictions": "System prompt restricts to store-related topics only",
    "no_training": "Azure OpenAI 'no-train' agreement — customer queries never used for model training"
  },

  "privacy": {
    "data_processed": "User query text only; no persistent storage after session (30-min TTL)",
    "anonymous_sessions": "No customer identification required; loyalty ID optional",
    "gdpr_lawful_basis": "Legitimate interests (service provision); consent for personalised queries"
  },

  "languages": {
    "online_supported": "40+ languages via Azure AI Translator",
    "offline_supported": "English, Hindi, German, French, Mandarin (top-5 by franchisee volume)"
  }
}
```

---

## Model Card 6 — Predictive Maintenance (UC6)

```json
{
  "model_name": "predictive-maintenance-{tenant_id}",
  "version": "pred-maint-v1.3.0",
  "last_updated": "2026-06-01",
  "approved_by": "Chief Data Officer",

  "model_details": {
    "description": "Two-model ensemble: Isolation Forest for real-time anomaly detection, Bi-directional LSTM for 72-hour failure prediction across 6 hardware components. Telemetry emitted by POS terminals every 60 seconds.",
    "type": "Anomaly detection + multi-label time-series classification",
    "predicted_components": ["thermal_printer", "barcode_scanner", "card_reader", "network_adapter", "touch_screen", "hardware_general"],
    "input_features": "15-metric aggregated telemetry vectors (1-hour windows)"
  },

  "intended_use": {
    "primary_use": "Predict POS hardware failures 72 hours in advance to enable proactive maintenance",
    "in_scope": ["POS terminals registered in Azure IoT Hub", "Windows and Android POS devices"],
    "out_of_scope": ["Network infrastructure", "Server hardware", "Mobile devices not enrolled"]
  },

  "performance": {
    "primary_metric": "Recall ≥ 70% of failure events with ≥ 48h lead time",
    "latest_evaluation": {
      "recall_at_72h": 0.743,
      "false_positive_rate": 0.112,
      "avg_lead_time_hours": 61.4,
      "evaluation_date": "2026-06-01",
      "total_failures_in_test": 284
    }
  },

  "training_data": {
    "description": "90 days of POS telemetry with confirmed failure event labels from ITSM tickets",
    "label_sources": ["ServiceNow incident records", "Manual technician failure reports"],
    "data_period": "Rolling 90-day window",
    "data_lineage": "Azure Purview: retailai-lineage/predictive-maintenance/{tenant_id}"
  },

  "fairness_and_bias": {
    "bias_risks": "None — no personal data; device-level predictions only",
    "known_limitations": [
      "Lower accuracy for device models not seen in training data",
      "False positive rate higher for newly enrolled devices (< 30 days telemetry)"
    ]
  },

  "explainability": {
    "method": "Feature contribution scores per prediction",
    "recipients": "ITSM ticket (auto-generated) + store manager push notification",
    "example": "Thermal printer failure predicted: roller_cycles (0.52) + head_temp_max (0.31) + error_count_trend (0.17)"
  },

  "human_oversight": {
    "automated_actions": "ServiceNow ticket created automatically for WARNING/CRITICAL predictions",
    "human_review": "Technician reviews ticket and decides maintenance action",
    "override": "Store manager can mark prediction as false positive — feeds model feedback"
  },

  "monitoring": {
    "drift_monitoring": "Evidently AI — daily PSI on telemetry feature distributions",
    "performance_monitoring": "Weekly recall evaluation against ITSM resolved tickets",
    "retrain_trigger": "PSI > 0.20 OR recall drops below 60%"
  }
}
```

---

## Model Card Governance Process

```
New Model → Training Complete
    │
    ├── CDO Review (3 business days)
    │    Review: performance metrics, bias results, data lineage, limitations
    │
    ├── CISO Review (fraud model only, 2 business days)
    │    Review: security implications, PCI-DSS compliance
    │
    ├── DPO Sign-off (personalisation model, 2 business days)
    │    Review: GDPR lawful basis, consent flows, data minimisation
    │
    └── Production Approval → Model Card published to:
         - Azure ML Model Registry (JSON tag)
         - Franchisee Admin Portal (PDF render)
         - Internal Confluence (architecture documentation)
```

---

## Related Documents

| Document | Reference |
|---|---|
| AI/ML Platform HLD | `01_HLD/HLD-005_AI_ML_Platform.md` |
| MLOps Pipeline LLD | `02_LLD/LLD-015_MLOps_Pipeline_Design.md` |
| MLOps Pipeline Config | `07_MLOps/MLOps_Pipeline_Config.md` |
| Drift Monitoring Config | `07_MLOps/Drift_Monitoring_Config.md` |
| Security & Compliance HLD | `01_HLD/HLD-007_Security_Compliance.md` |

