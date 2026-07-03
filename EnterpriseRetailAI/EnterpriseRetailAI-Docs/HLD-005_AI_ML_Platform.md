# HLD-005 — AI/ML Platform
## EnterpriseRetailAI · Artificial Intelligence & Machine Learning Architecture

---

| Attribute | Value |
|---|---|
| Document ID | HLD-005 |
| Type | High-Level Design |
| Version | 1.0 |
| Status | Approved |
| Date | June 2026 |

---

## 1. Purpose

This document defines the high-level design of the AI/ML Platform — the end-to-end system for training, validating, deploying, and monitoring all six AI use cases embedded in the EnterpriseRetailAI platform. It covers the Azure ML infrastructure, Azure OpenAI integration, edge AI deployment via IoT Edge, and the MLOps governance framework.

---

## 2. AI Platform Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                          AI/ML PLATFORM OVERVIEW                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐   │
│  │                    DATA INGESTION & FEATURE LAYER                   │   │
│  │                                                                       │   │
│  │  Azure Data Lake Gen2 (raw events) ──► Azure ML Feature Store        │   │
│  │  Synapse Analytics (feature engineering pipelines)                  │   │
│  │  Azure Purview (data lineage + governance)                           │   │
│  │                                                                       │   │
│  │  Feature domains:                                                    │   │
│  │  ├ Transaction features (sales velocity, basket stats)              │   │
│  │  ├ Customer features (purchase history, segments, RFM)              │   │
│  │  ├ Product features (category, margin, seasonality index)           │   │
│  │  ├ Device features (POS telemetry, error rates)                     │   │
│  │  └ Contextual features (weather, events, calendar)                  │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                │                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐   │
│  │                    AZURE MACHINE LEARNING WORKSPACE                 │   │
│  │                                                                       │   │
│  │  ┌────────────────────┐   ┌───────────────────┐   ┌───────────────┐  │   │
│  │  │ Training Pipelines │   │  Model Registry   │   │ Experiment    │  │   │
│  │  │ (per use case)     │   │  (versioned,      │   │ Tracking      │  │   │
│  │  │                    │   │   signed, hashed) │   │ (MLflow)      │  │   │
│  │  │ Compute:           │   │                   │   │               │  │   │
│  │  │ ├ CPU clusters     │   │ Models:           │   │ Auto-logging: │  │   │
│  │  │ ├ GPU clusters     │   │ ├ fraud-detect-v* │   │ params,      │  │   │
│  │  │ └ Spot instances   │   │ ├ demand-fcst-v*  │   │ metrics,     │  │   │
│  │  │   (80% cost save)  │   │ ├ promo-rank-v*   │   │ artifacts    │  │   │
│  │  └────────────────────┘   │ ├ cv-items-v*     │   └───────────────┘  │   │
│  │                           │ ├ pred-maint-v*   │                      │   │
│  │  ┌────────────────────┐   │ └ (ONNX exports) │   ┌───────────────┐  │   │
│  │  │ AutoML             │   └───────────────────┘   │ Responsible   │  │   │
│  │  │ (baseline models   │                           │ AI Dashboard  │  │   │
│  │  │  for new tenants)  │   ┌───────────────────┐   │ SHAP + LIME   │  │   │
│  │  └────────────────────┘   │ Managed Endpoints │   │ Fairlearn     │  │   │
│  │                           │ (per-tenant,      │   │ Bias check    │  │   │
│  │                           │  AKS-hosted)      │   └───────────────┘  │   │
│  │                           └───────────────────┘                      │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                │                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐   │
│  │                    AZURE OPENAI PLATFORM                            │   │
│  │                                                                       │   │
│  │  Models deployed:                                                    │   │
│  │  ├ GPT-4o (NLP store assistant — chat completions)                  │   │
│  │  ├ text-embedding-ada-002 (customer + product embeddings)           │   │
│  │  └ whisper-1 (voice-to-text for store assistant)                    │   │
│  │                                                                       │   │
│  │  Azure AI Content Safety (guardrails on all LLM responses)          │   │
│  │  Azure AI Search (vector + semantic retrieval for RAG)              │   │
│  │  Azure AI Translator (40+ language support for NLP assistant)       │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                │                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐   │
│  │                    DEPLOYMENT TIERS                                 │   │
│  │                                                                       │   │
│  │  Cloud (AKS)          Store Edge (IoT Edge)    POS (ONNX bundle)    │   │
│  │  ├ Full models         ├ Quantised ONNX          ├ Tiny ONNX models  │   │
│  │  ├ GPT-4o / Ada-002    ├ YOLOv8n                 ├ LightGBM fraud    │   │
│  │  ├ TFT demand fcst     ├ LightGBM fraud-edge      ├ Promo ranker      │   │
│  │  ├ CF recommender      ├ Phi-3 Mini SLM           └ < 100MB total    │   │
│  │  └ Online inference    └ TFT-lite forecast                           │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
│                                │                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐   │
│  │                    MLOPS MONITORING                                 │   │
│  │  Evidently AI: data drift + concept drift (daily)                   │   │
│  │  Azure ML Monitor: model performance vs. baseline                   │   │
│  │  Grafana dashboards: per-model, per-tenant KPIs                     │   │
│  │  Auto-trigger retraining: drift score > threshold                   │   │
│  └───────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. AI Use Case Design Summary

### UC1 — Demand Forecasting & Replenishment

| Attribute | Detail |
|---|---|
| Model | Temporal Fusion Transformer (TFT) |
| Framework | PyTorch + PyTorch Forecasting |
| Training data | 2+ years sales history per SKU per store |
| Feature store | Azure ML Feature Store (daily refresh) |
| Training schedule | Daily incremental; full retrain weekly |
| Inference | Batch nightly (per-tenant AKS job) + on-demand API |
| Output | 7/14/30-day forecasts per SKU per store |
| Downstream | Replenishment Service → ERP purchase order |
| KPI | MAPE < 12% (measured on holdout 30-day window) |
| Tenant isolation | Separate feature set + model per franchisee |

### UC2 — Fraud Detection

| Attribute | Detail |
|---|---|
| Models | LightGBM (POS ONNX) + Neural Net (store edge) + Graph NN (cloud batch) |
| Framework | LightGBM / scikit-learn / PyTorch Geometric |
| Features | 35-feature vector: transaction, behavioural, device, card, contextual |
| Inference latency | < 50ms (POS ONNX), < 200ms (store edge) |
| Output | Score 0.0–1.0 + reason codes |
| Action | Allow / Step-up / Decline + alert |
| KPI | TPR > 94%, FPR < 2% on test set |
| Retraining | Weekly (auto) + triggered on drift |

### UC3 — Personalised Promotions & Loyalty

| Attribute | Detail |
|---|---|
| Models | Collaborative filtering (Matrix Factorisation) + Contextual Bandits |
| Framework | Surprise / Vowpal Wabbit (bandits) |
| Customer features | RFM scores, category affinity, brand preference, time-of-day patterns |
| Contextual features | Basket contents, weather, stock levels, promotion budget |
| Inference | Real-time (< 500ms) via AKS managed endpoint |
| Output | Top-3 ranked promotions + personalisation score |
| KPI | Basket value lift > 8% vs. control (A/B test) |
| Consent | GDPR opt-in required; anonymous-segment fallback |

### UC4 — Computer Vision (Self-Checkout & Shelf Analytics)

| Attribute | Detail |
|---|---|
| Models | YOLOv8n (item recognition) + ResNet-50 (planogram) + Two-stream CNN (anti-theft) |
| Framework | Ultralytics YOLOv8 / PyTorch |
| Training data | Per-tenant SKU image dataset (min 200 images/SKU) |
| Hardware | Store edge + optional NVIDIA Jetson Orin for GPU acceleration |
| Inference | Store edge IoT Edge module |
| Self-checkout accuracy | > 98.5% item recognition (p95 confidence) |
| Shelf analytics | Planogram compliance score; out-of-stock alerts |
| Training | Per-franchisee fine-tune from HQ base model |

### UC5 — NLP Store Assistant

| Attribute | Detail |
|---|---|
| Cloud model | Azure OpenAI GPT-4o (chat completions) |
| Offline model | Phi-3-Mini-4K-Instruct (GGUF, llama.cpp on store edge) |
| RAG | Azure AI Search (hybrid semantic + keyword) |
| Knowledge base | Product catalogue + store policies + FAQs + promotions |
| Embedding | text-embedding-ada-002 (cloud) / all-MiniLM-L6-v2 (edge) |
| Voice | Whisper-1 (cloud STT) / Whisper-tiny (edge) |
| Languages | 40+ via Azure AI Translator |
| Intent classes | 12 (product search, price, stock, returns, loyalty, complaints, …) |
| Guardrails | Azure AI Content Safety (all responses filtered) |

### UC6 — Predictive Maintenance

| Attribute | Detail |
|---|---|
| Models | Isolation Forest (anomaly) + LSTM (failure prediction) |
| Framework | scikit-learn / Keras |
| Telemetry | 15-metric vector from POS (CPU, memory, peripheral error rates, etc.) |
| Infrastructure | Azure IoT Hub → Azure Digital Twins → Azure ML |
| Horizon | 72-hour failure prediction |
| Alert | Triggered → ServiceNow ticket created automatically |
| KPI | > 70% failure events predicted with > 48h lead time |

---

## 4. MLOps Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        MLOps CD4ML PIPELINE                            │
│                                                                         │
│  1. DATA VALIDATION                                                     │
│     Azure ML Data Asset versioning                                     │
│     Great Expectations: schema + distribution checks                   │
│     Fail if: missing > 5% of required features                         │
│                                                                         │
│  2. FEATURE ENGINEERING                                                 │
│     Synapse Spark pipeline → Azure ML Feature Store                    │
│     Materialized feature sets with point-in-time correctness           │
│                                                                         │
│  3. MODEL TRAINING                                                      │
│     Azure ML Pipeline (Python SDK v2)                                  │
│     Compute: CPU cluster (spot) for GBM; GPU cluster for DL           │
│     Hyperparameter tuning: Azure ML Sweep (Bayesian)                   │
│     Experiment tracking: MLflow (auto-logged)                          │
│                                                                         │
│  4. MODEL EVALUATION                                                    │
│     Hold-out test set evaluation (30% split)                           │
│     Bias check: Fairlearn (demographic parity, equal opportunity)      │
│     Explainability: SHAP values computed + stored                      │
│     Gate: must beat baseline KPI thresholds to proceed                 │
│                                                                         │
│  5. MODEL REGISTRATION                                                  │
│     Azure ML Model Registry: version + SHA-256 hash + model card      │
│     CDO sign-off required for promotion to production                  │
│                                                                         │
│  6. DEPLOYMENT (CD)                                                     │
│     Cloud:      AKS managed endpoint update (blue-green)               │
│     Store Edge: IoT Hub deployment manifest update → OTA               │
│     POS:        ONNX bundle signed → IoT Hub file upload               │
│     Traffic:    Canary (5%) → staged (25%) → full (100%)               │
│                                                                         │
│  7. MONITORING                                                          │
│     Evidently AI: daily data drift + concept drift reports             │
│     Azure ML Monitor: performance vs. production baseline              │
│     Auto-retrain trigger: PSI > 0.2 (feature drift threshold)         │
│     Auto-rollback: if KPI degrades > 10% vs. previous version         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Responsible AI Framework

### 5.1 Bias Controls

| Use Case | Protected Attributes Monitored | Mitigation |
|---|---|---|
| Fraud detection | Age, gender (if provided), nationality | Equal TPR/FPR across demographic groups (Fairlearn EqualizedOdds) |
| Personalised promos | Age, gender | Demographic parity in offer rates |
| NLP assistant | Language, nationality | Equal intent classification accuracy across languages |
| CV self-checkout | Skin tone (item placement angle bias) | Diverse training data; augmentation |

### 5.2 Explainability

| Use Case | Explainability Method | Who Gets Explanation |
|---|---|---|
| Fraud decline | SHAP top-3 features | Store manager + audit log |
| Demand forecast | Feature importance + confidence interval | Store manager dashboard |
| Promo recommendation | LIME + promotion reason | Customer-facing screen |
| Predictive maintenance | Feature contribution | ITSM ticket |

### 5.3 Model Cards

All production models are published with model cards including:
- Model purpose and intended use
- Performance metrics (overall + per-segment)
- Bias evaluation results
- Data provenance
- Limitations and out-of-scope uses
- Contact and escalation information

---

## 6. AI Governance Controls

| Control | Implementation |
|---|---|
| Model approval gate | CDO sign-off in Azure ML model registry |
| Audit trail | All model deployments logged to immutable Azure Immutable Blob |
| Data lineage | Azure Purview tracks data → feature → model → prediction |
| GDPR Art 22 (automated decisions) | Human override available for fraud decline at POS |
| Model versioning | Semantic versioning; old versions retained (never deleted) |
| Shadow mode testing | New models run in shadow against production for 7 days before A/B |

---

## 7. Related Documents

| Document | Reference |
|---|---|
| Fraud Detection LLD | `02_LLD/LLD-004_Fraud_Detection_Service.md` |
| Demand Forecasting LLD | `02_LLD/LLD-005_Demand_Forecasting_Pipeline.md` |
| Personalisation LLD | `02_LLD/LLD-006_Personalisation_Promotions_Engine.md` |
| CV Self-Checkout LLD | `02_LLD/LLD-007_CV_Self_Checkout.md` |
| NLP Assistant LLD | `02_LLD/LLD-008_NLP_Store_Assistant.md` |
| Predictive Maintenance LLD | `02_LLD/LLD-009_Predictive_Maintenance.md` |
| MLOps Pipeline LLD | `02_LLD/LLD-015_MLOps_Pipeline_Design.md` |
