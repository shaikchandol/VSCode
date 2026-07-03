# SKILL.md — MLOps & Model Drift Analysis

**Skill Name:** mlops-drift-analysis

**Purpose:** Help AI agents navigate model lifecycle, training pipelines, drift monitoring, and retraining strategies across the six embedded AI use cases.

---

## When to Use This Skill

Use this skill when:
- **Model lifecycle questions** — "How do we train and deploy the fraud detection model?"
- **Drift monitoring** — "What triggers a model retraining? What are the drift thresholds?"
- **MLOps pipelines** — "What's the end-to-end training pipeline for demand forecasting?"
- **Model deployment** — "Where does the personalisation model run? How is it versioned?"
- **Performance metrics** — "What are the SLAs and thresholds for each AI use case?"
- **Model cards & specs** — "What inputs, outputs, and performance characteristics does the fraud model have?"

Do NOT use this skill for:
- General AI/ML architecture (use [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) directly)
- Code-level implementation details
- Non-AI architecture questions

---

## Six AI Use Cases Quick Map

| Use Case | Model | Training | Inference | LLD | Model Card | Config |
|---|---|---|---|---|---|---|
| **Fraud Detection** | XGBoost (ONNX) | Azure ML | POS + Cloud | [LLD-004](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md) | [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) | [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md) |
| **Demand Forecasting** | Temporal Fusion Transformer | Azure ML | Cloud | [LLD-005](EnterpriseRetailAI-Docs/LLD-005_Demand_Forecasting_Pipeline.md) | [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) | [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md) |
| **Personalisation** | Collab filtering + bandits | Azure ML | Store Edge + Cloud | [LLD-006](EnterpriseRetailAI-Docs/LLD-006_Personalisation_Promotions_Engine.md) | [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) | [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md) |
| **CV Self-Checkout** | YOLOv8 (ONNX) | Azure ML | Store Edge | [LLD-007](EnterpriseRetailAI-Docs/LLD-007_CV_Self_Checkout.md) | [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) | [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md) |
| **NLP Assistant** | GPT-4o + RAG | N/A (pretrained) | Cloud + Phi-3 (offline) | [LLD-008](EnterpriseRetailAI-Docs/LLD-008_NLP_Store_Assistant.md) | [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) | [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md) |
| **Predictive Maintenance** | Isolation Forest | Azure ML | Store Edge | [LLD-009](EnterpriseRetailAI-Docs/LLD-009_Predictive_Maintenance.md) | [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) | [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md) |

---

## Workflow: Model Training & Deployment

### Step 1: Identify the Use Case
Map the user's question to one of the six models using the table above.

### Step 2: Locate the LLD & Model Card
- **LLD (LLD-004 through LLD-009):** Describes the model's purpose, inputs, outputs, and inference location
- **Model_Cards.md:** Full model specifications including training data, performance metrics, and SLAs
- **MLOps_Pipeline_Config.md:** Training pipeline definition (frequency, data sources, hyperparameters)

### Step 3: Understand the Training Pipeline
All models trained in Azure ML follow this pattern:

```
Data Preparation (feature engineering)
    ↓
Model Training (Azure ML pipeline)
    ↓
Model Validation (metrics thresholds)
    ↓
Model Registration (Azure ML Model Registry)
    ↓
Drift Monitoring (continuous metrics)
    ↓
[Drift Detected?]
    ├─ Yes → Trigger Retraining
    └─ No → Continue Inference
    ↓
Model Deployment (ONNX export for edge, or cloud endpoint)
```

**Reference:** [LLD-015_MLOps_Pipeline_Design.md](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md)

### Step 4: Check Drift Monitoring Configuration
Open [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md) to find:
- **Drift Thresholds:** What triggers a retraining (e.g., prediction drift > 10%)
- **Monitoring Frequency:** How often metrics are checked (hourly, daily, weekly)
- **Alert Channels:** Where drift alerts go (email, Slack, Azure Monitor)
- **Retraining SLA:** How quickly a model must be retrained after drift detected

### Step 5: Locate Deployment Strategy
Based on the model type:
- **ONNX Models (Fraud, CV):** Exported to ONNX format and deployed to POS/Store Edge
  - See [ADR-005_ONNX_POS_Inference.md](EnterpriseRetailAI-Docs/ADR-005_ONNX_POS_Inference.md)
  - Versioning: Model version stored with ONNX artifact in Azure Blob Storage
- **Cloud-only Models (Demand, Personalisation, NLP):** Deployed to Azure Container Instances or AKS
  - Versioning: Azure ML Model Registry version + container image tag
- **Phi-3 Offline Fallback (NLP):** Pre-packaged with store edge, updated via sync

---

## Example: Fraud Model Retraining Workflow

**User Question:** "How do we know when to retrain the fraud detection model? What's the process?"

**Step 1:** Fraud Detection → LLD-004, Model_Cards.md, Drift_Monitoring_Config.md

**Step 2:** Read [LLD-004_Fraud_Detection_Service.md](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md)
- Model: XGBoost (ONNX)
- Inference: POS terminal (real-time) + Cloud (batch scoring)
- Features: Transaction amount, merchant category, customer history, geographic anomalies

**Step 3:** Check [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) for fraud model spec
- Training data: 2 years of labeled transactions
- Performance target: 95% precision, 85% recall
- Inference latency: <100ms on POS
- Output: Fraud score (0-1) + risk category (low/medium/high)

**Step 4:** Review [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md)
- **Prediction drift:** Monitor if fraud scores shift > 10% week-over-week
- **Feature drift:** Check if transaction feature distributions change (e.g., average amount increases 20%)
- **Label drift:** If fraud rate in labeled test set changes > 5%, trigger review
- **Monitoring frequency:** Hourly aggregation, daily alert evaluation
- **Retraining SLA:** If drift detected, retrain within 24 hours; deploy within 48 hours

**Step 5:** Review [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md)
- **Scheduled retraining:** Weekly batch on Monday 2 AM UTC (uses latest 2 weeks of data)
- **On-demand retraining:** Triggered by drift alerts (>10% prediction drift)
- **Data sources:** Transaction events from Cloud event hub → Feature store
- **Hyperparameter tuning:** Automated via Azure ML AutoML
- **Validation:** Hold-out test set from previous week; must match historical precision/recall

**Step 6:** Deployment
- Export trained model to ONNX format
- Version in Azure Blob Storage: `fraud-model-v1.2.3.onnx`
- Update POS terminal via sync manager (binary push to all terminals)
- Coordinate with cloud endpoint update (blue-green deployment)

**Answer:**
> The fraud detection model retrains on a **weekly schedule** (Monday 2 AM UTC) and **immediately upon drift detection** (>10% prediction drift month-over-month). 
>
> **Monitoring:** Drift is detected hourly by checking if transaction fraud scores or feature distributions shift >10% from baseline. If detected, an alert goes to the ML ops team.
>
> **Retraining Process:** 
> 1. Fetch latest 2 weeks of labeled transaction data from cloud event hub
> 2. Run automated hyperparameter tuning (Azure ML AutoML)
> 3. Validate against hold-out test set (must maintain ≥95% precision, ≥85% recall)
> 4. Export to ONNX format
>
> **Deployment:**
> - POS terminals: Model pushed via sync manager (all terminals updated within 12 hours)
> - Cloud: Blue-green deployment to AKS (zero downtime)
> - Timeline: 24h to retrain, 48h to deploy
>
> See [LLD-004](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md), [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md), [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md), [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md).

---

## Key Patterns Across All Models

### 1. **Azure ML as Training Hub**
- All models (except GPT-4o) train in Azure ML
- Automated pipelines orchestrated by Azure ML Pipelines
- Model Registry stores versioned artifacts

**Reference:** [LLD-015_MLOps_Pipeline_Design.md](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md)

### 2. **ONNX for Edge Inference**
- Fraud, CV self-checkout, and promo ranking use ONNX-exportable models
- Inference latency <100ms on POS terminal
- Models versioned as ONNX binaries in cloud storage

**Reference:** [ADR-005_ONNX_POS_Inference.md](EnterpriseRetailAI-Docs/ADR-005_ONNX_POS_Inference.md)

### 3. **Three-Tier Inference**
- **POS (Edge):** Real-time, <100ms, ONNX models
- **Store Edge:** Batch, local feature store, Phi-3 NLP fallback
- **Cloud:** Heavy compute, model training, batch scoring

**Reference:** [HLD-005_AI_ML_Platform.md](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md)

### 4. **Feature Store**
- Shared feature definitions across models
- Features computed at training time (offline) and inference time (online)
- Store-local feature store at Store Edge for offline fallback

**Reference:** [LLD-015_MLOps_Pipeline_Design.md](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md)

### 5. **Drift Monitoring at Every Model**
- Prediction drift (model outputs), feature drift (input distributions), label drift (ground truth changes)
- Monitored hourly, evaluated daily
- Triggers retraining if threshold exceeded

**Reference:** [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md)

---

## Common Retraining Scenarios

| Scenario | Trigger | Response | Timeline |
|---|---|---|---|
| **Scheduled Retraining** | Weekly schedule (Monday 2 AM UTC) | Standard pipeline, all models | 24h to completion |
| **Drift Detected** | Prediction drift > 10% | Immediate retraining, alert ops team | 24h to completion, 48h to deploy |
| **Feature Schema Change** | New fields in transaction/inventory | Retrain all dependent models | 48h to completion |
| **Data Quality Issue** | >5% null values in key feature | Pause retraining, investigate | On-demand investigation |
| **Model Degradation** | Precision/recall drops below SLA | Manual review + emergency retrain | 4h emergency SLA |

---

## Reference Map

| Question | Document |
|---|---|
| What inputs/outputs does each model have? | [Model_Cards.md](EnterpriseRetailAI-Docs/Model_Cards.md) |
| How do we train models? | [MLOps_Pipeline_Config.md](EnterpriseRetailAI-Docs/MLOps_Pipeline_Config.md) |
| How do we detect drift? | [Drift_Monitoring_Config.md](EnterpriseRetailAI-Docs/Drift_Monitoring_Config.md) |
| Where does each model run? | [HLD-005_AI_ML_Platform.md](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) |
| How do we export to ONNX? | [ADR-005_ONNX_POS_Inference.md](EnterpriseRetailAI-Docs/ADR-005_ONNX_POS_Inference.md) |
| Full MLOps architecture? | [LLD-015_MLOps_Pipeline_Design.md](EnterpriseRetailAI-Docs/LLD-015_MLOps_Pipeline_Design.md) |
| Fraud model specifics? | [LLD-004_Fraud_Detection_Service.md](EnterpriseRetailAI-Docs/LLD-004_Fraud_Detection_Service.md) |
| Demand forecasting specifics? | [LLD-005_Demand_Forecasting_Pipeline.md](EnterpriseRetailAI-Docs/LLD-005_Demand_Forecasting_Pipeline.md) |
| All 6 use cases overview? | [HLD-005_AI_ML_Platform.md](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md) |

---

## Tips for Agents

1. **Always start with the model card** — It has specifications, performance targets, and SLAs
2. **Check the LLD for deployment context** — Understand where the model runs (POS/Store/Cloud)
3. **Cross-reference drift config** — Know the drift thresholds that trigger retraining
4. **Understand the three-tier inference** — Explain how fallbacks work when a tier is offline
5. **Mention feature store** — Explain how feature consistency is maintained across tiers
6. **Cite retraining SLA** — Include timeline expectations (24h retrain, 48h deploy)

---

## When You Don't Know the Answer

If a user asks about a model not in the six use cases:
1. Check if the question belongs to general AI/ML architecture (use [HLD-005](EnterpriseRetailAI-Docs/HLD-005_AI_ML_Platform.md))
2. If a model exists but is missing a card, note this as a gap
3. Point to the nearest analogous use case (e.g., "Fraud uses ONNX like CV does")
