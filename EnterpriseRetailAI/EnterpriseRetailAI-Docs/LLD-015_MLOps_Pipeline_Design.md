# LLD-015 — MLOps Pipeline Design
## EnterpriseRetailAI · Azure ML Pipelines, Model Registry, Drift Monitoring, CD4ML

---

| Document ID | LLD-015 | Version | 1.0 | Status | Approved | Date | June 2026 |

---

## 1. MLOps Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        MLOps PLATFORM                                     │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  DATA LAYER                                                                │
│  Azure Data Lake Gen2 ──► Azure ML Feature Store ──► Training Datasets    │
│  Azure Purview (lineage) │ Great Expectations (quality) │ Schema Registry  │
│                                                                            │
│  TRAINING LAYER                                                            │
│  Azure ML Pipelines (Python SDK v2)                                        │
│  ├── UC1: Demand Forecasting Pipeline    (daily + weekly)                  │
│  ├── UC2: Fraud Detection Pipeline       (weekly + drift-triggered)        │
│  ├── UC3: Personalisation Pipeline       (weekly + online bandit update)   │
│  ├── UC4: CV Self-Checkout Pipeline      (per new SKU batch)               │
│  ├── UC5: NLP Knowledge Base Pipeline    (nightly KB refresh)              │
│  └── UC6: Predictive Maintenance Pipeline (weekly)                         │
│                                                                            │
│  REGISTRY LAYER                                                            │
│  Azure ML Model Registry (versioned, signed, hashed)                      │
│  MLflow Experiment Tracking (all runs, params, metrics, artifacts)         │
│                                                                            │
│  DEPLOYMENT LAYER                                                          │
│  Cloud: AKS Managed Endpoints (blue-green, canary)                        │
│  Edge:  IoT Hub deployment manifests → OTA to store nodes                 │
│  POS:   ONNX bundle signing → IoT Hub file upload → device sync           │
│                                                                            │
│  MONITORING LAYER                                                          │
│  Evidently AI (data + concept drift) │ Azure ML Monitor │ Grafana          │
│  Auto-retrain triggers │ Auto-rollback │ Alert routing                     │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Azure ML Pipeline: Fraud Detection (UC2)

```yaml
# azure_ml/pipelines/fraud_detection_pipeline.yaml
$schema: https://azuremlschemas.azureedge.net/latest/pipelineJob.schema.json
type: pipeline

display_name: fraud_detection_training_pipeline
description: Weekly fraud model retraining per franchisee tenant

settings:
  default_compute: cpu-cluster-spot
  default_datastore: workspaceblobstore
  continue_on_step_failure: false

inputs:
  tenant_id:
    type: string
  training_window_days:
    type: integer
    default: 90
  min_fraud_samples:
    type: integer
    default: 1000

jobs:
  data_validation:
    type: command
    component: azureml:data_validator:1.0.0
    inputs:
      raw_data:
        type: uri_folder
        path: azureml://datastores/datalake/paths/${{inputs.tenant_id}}/ml-training/fraud-detection/
      schema_file: azureml:fraud_feature_schema:2.1.0
      max_missing_pct: 5.0
    outputs:
      validated_data:
        type: uri_folder

  feature_engineering:
    type: command
    component: azureml:fraud_feature_engineer:1.2.0
    inputs:
      validated_data: ${{parent.jobs.data_validation.outputs.validated_data}}
      tenant_id: ${{inputs.tenant_id}}
      window_days: ${{inputs.training_window_days}}
    outputs:
      feature_set:
        type: mltable
    compute: gpu-cluster-spot

  model_training:
    type: command
    component: azureml:fraud_lgbm_trainer:2.0.0
    inputs:
      feature_set: ${{parent.jobs.feature_engineering.outputs.feature_set}}
      tenant_id: ${{inputs.tenant_id}}
      min_fraud_samples: ${{inputs.min_fraud_samples}}
    outputs:
      model_artifacts:
        type: uri_folder
      training_metrics:
        type: uri_file

  bias_evaluation:
    type: command
    component: azureml:fairlearn_evaluator:1.0.0
    inputs:
      model_artifacts: ${{parent.jobs.model_training.outputs.model_artifacts}}
      feature_set: ${{parent.jobs.feature_engineering.outputs.feature_set}}
      protected_features: ["card_bin_country_mismatch", "card_type_encoded"]
      max_tpr_disparity: 0.05
    outputs:
      bias_report:
        type: uri_folder

  onnx_export:
    type: command
    component: azureml:onnx_exporter:1.1.0
    inputs:
      model_artifacts: ${{parent.jobs.model_training.outputs.model_artifacts}}
      target_opset: 17
      quantize: true
      quantize_type: QInt8
    outputs:
      onnx_bundle:
        type: uri_folder

  model_registration:
    type: command
    component: azureml:model_registrar:1.0.0
    inputs:
      onnx_bundle: ${{parent.jobs.onnx_export.outputs.onnx_bundle}}
      training_metrics: ${{parent.jobs.model_training.outputs.training_metrics}}
      bias_report: ${{parent.jobs.bias_evaluation.outputs.bias_report}}
      tenant_id: ${{inputs.tenant_id}}
      model_name: fraud-detection
      kpi_gates:
        tpr_at_fpr_02: 0.94
        fpr_at_tpr_94: 0.02
        auc: 0.98
    outputs:
      registered_model_id:
        type: uri_file
```

---

## 3. Model Training Components

### Fraud Model Trainer Component

```python
# components/fraud_lgbm_trainer/train.py
import argparse
import lightgbm as lgb
import mlflow
import pandas as pd
import numpy as np
from pathlib import Path
from sklearn.model_selection import train_test_split

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--feature_set",        type=str)
    parser.add_argument("--model_artifacts",    type=str)
    parser.add_argument("--training_metrics",   type=str)
    parser.add_argument("--tenant_id",          type=str)
    parser.add_argument("--min_fraud_samples",  type=int, default=1000)
    args = parser.parse_args()

    mlflow.lightgbm.autolog()

    # Load features
    df = pd.read_parquet(args.feature_set)
    X = df.drop(columns=["label", "idempotency_key", "tenant_id"])
    y = df["label"]

    # Validate fraud sample count
    fraud_count = y.sum()
    if fraud_count < args.min_fraud_samples:
        raise ValueError(
            f"Insufficient fraud samples: {fraud_count} < {args.min_fraud_samples}. "
            "Cannot train reliable model."
        )

    # Stratified split preserving fraud rate
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=42
    )

    scale_pos_weight = (len(y_train) - y_train.sum()) / y_train.sum()

    with mlflow.start_run():
        mlflow.log_param("tenant_id", args.tenant_id)
        mlflow.log_param("fraud_count_train", int(y_train.sum()))
        mlflow.log_param("scale_pos_weight", float(scale_pos_weight))

        dtrain = lgb.Dataset(X_train, label=y_train)
        dval   = lgb.Dataset(X_val,   label=y_val, reference=dtrain)

        params = {
            "objective":         "binary",
            "metric":            ["binary_logloss", "auc"],
            "num_leaves":        63,
            "max_depth":         8,
            "learning_rate":     0.05,
            "scale_pos_weight":  scale_pos_weight,
            "min_child_samples": 20,
            "feature_fraction":  0.8,
            "bagging_fraction":  0.8,
            "bagging_freq":      5,
            "reg_alpha":         0.1,
            "reg_lambda":        0.2,
        }

        callbacks = [lgb.early_stopping(50), lgb.log_evaluation(100)]
        model = lgb.train(params, dtrain, num_boost_round=500,
                          valid_sets=[dval], callbacks=callbacks)

        # Evaluate
        y_proba = model.predict(X_val)
        from sklearn.metrics import roc_auc_score, roc_curve
        auc = roc_auc_score(y_val, y_proba)
        fprs, tprs, thresholds = roc_curve(y_val, y_proba)
        tpr_at_fpr_02 = float(tprs[np.searchsorted(fprs, 0.02)])

        mlflow.log_metric("auc", auc)
        mlflow.log_metric("tpr_at_fpr_02", tpr_at_fpr_02)

        # Gate check
        assert tpr_at_fpr_02 >= 0.94, \
            f"TPR {tpr_at_fpr_02:.4f} below 0.94 gate. Training rejected."

        # Save artifacts
        Path(args.model_artifacts).mkdir(parents=True, exist_ok=True)
        model.save_model(f"{args.model_artifacts}/fraud_model.txt")
        mlflow.lightgbm.log_model(model, "fraud_model")

        metrics = {"auc": auc, "tpr_at_fpr_02": tpr_at_fpr_02}
        pd.Series(metrics).to_json(args.training_metrics)

if __name__ == "__main__":
    main()
```

---

## 4. Model Registry Strategy

```python
from azure.ai.ml import MLClient
from azure.ai.ml.entities import Model
from azure.ai.ml.constants import AssetTypes
import hashlib, json

def register_model(
    ml_client: MLClient,
    model_path: str,
    model_name: str,
    tenant_id: str,
    metrics: dict,
    tags: dict,
) -> str:
    """
    Register model in Azure ML with:
    - SHA-256 hash for integrity verification
    - KPI gate validation
    - Mandatory model card
    - Tenant-scoped naming
    """
    # Compute SHA-256 hash of ONNX model file
    with open(f"{model_path}/fraud_model_int8.onnx", "rb") as f:
        model_hash = hashlib.sha256(f.read()).hexdigest()

    # Build model card
    model_card = {
        "model_name":    f"{model_name}-{tenant_id}",
        "tenant_id":     tenant_id,
        "framework":     "LightGBM → ONNX INT8",
        "kpi_metrics":   metrics,
        "sha256":        model_hash,
        "training_date": pd.Timestamp.now().isoformat(),
        "bias_checked":  True,
        "explainability": "SHAP values computed",
        "intended_use":  "Real-time fraud scoring at POS terminal",
        "limitations":   "Reduced accuracy in OFFLINE mode (18-feature fallback)",
    }

    model = Model(
        path        = model_path,
        name        = f"{model_name}-{tenant_id}",
        type        = AssetTypes.CUSTOM_MODEL,
        description = f"Fraud detection model for tenant {tenant_id}",
        tags        = {
            **tags,
            "tenant_id":   tenant_id,
            "sha256":      model_hash,
            "auc":         str(metrics.get("auc", "")),
            "tpr_at_fpr_02": str(metrics.get("tpr_at_fpr_02", "")),
            "model_card":  json.dumps(model_card),
        },
    )

    registered = ml_client.models.create_or_update(model)
    return registered.id
```

---

## 5. CD4ML Deployment Pipeline

```python
# deployment/deploy_model.py

class ModelDeploymentPipeline:
    """
    Orchestrates blue-green deployment to all targets:
    Cloud (AKS) → Store Edge (IoT Hub) → POS (ONNX bundle)
    """
    def deploy(
        self,
        model_id:  str,
        tenant_id: str,
        use_case:  str,         # "fraud", "demand", "promo", etc.
        canary_pct: int = 5,    # start with 5% canary traffic
    ):
        # 1. Shadow test for 7 days (new model runs alongside old, no effect)
        self._run_shadow_test(model_id, tenant_id, days=7)

        # 2. Canary: 5% traffic to new model, monitor KPIs
        endpoint_name = f"{use_case}-{tenant_id}"
        self._deploy_canary(endpoint_name, model_id, canary_pct)

        # 3. Monitor canary for 48 hours
        kpi_passed = self._monitor_canary(endpoint_name, hours=48)
        if not kpi_passed:
            self._rollback(endpoint_name)
            raise DeploymentGateFailed(f"Canary KPI gate failed for {model_id}")

        # 4. Staged rollout: 25% → 50% → 100%
        for pct in [25, 50, 100]:
            self._update_traffic_split(endpoint_name, pct)
            if not self._monitor_canary(endpoint_name, hours=12):
                self._rollback(endpoint_name)
                raise DeploymentGateFailed(f"Rollout failed at {pct}%")

        # 5. Deploy to Store Edge via IoT Hub
        self._deploy_to_iot_edge(model_id, tenant_id, use_case)

        # 6. Package and push ONNX bundle to POS terminals
        if use_case in ["fraud", "promo"]:
            self._push_onnx_to_pos(model_id, tenant_id, use_case)

    def _deploy_to_iot_edge(self, model_id, tenant_id, use_case):
        """Update IoT Hub deployment manifest → triggers OTA on all store nodes."""
        module_name  = f"{use_case}-edge"
        image_tag    = self._get_container_image(model_id)
        manifest     = self._build_iot_manifest(module_name, image_tag)
        self.iot_client.update_configuration(
            config_id   = f"{tenant_id}-{module_name}",
            content     = manifest,
            target_condition = f"tags.tenant_id='{tenant_id}'",
            priority    = 10,
        )

    def _push_onnx_to_pos(self, model_id, tenant_id, use_case):
        """
        Signs the ONNX bundle with HQ private key.
        Uploads to IoT Hub file store.
        POS terminals download on next scheduled check-in.
        """
        bundle = self._package_onnx_bundle(model_id, use_case)
        signed = self._sign_bundle(bundle)
        self.iot_client.upload_file(
            device_group = tenant_id,
            file_path    = f"models/{use_case}_model_v{bundle.version}.onnx",
            content      = signed,
        )
```

---

## 6. Drift Monitoring Pipeline

```python
# monitoring/drift_monitor.py
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, TargetDriftPreset
from evidently.metrics import DatasetDriftMetric
from azureml.core import Run
import pandas as pd

class ModelDriftMonitor:
    """
    Runs daily against production prediction logs.
    Triggers auto-retraining if PSI > 0.20 on key features.
    """
    PSI_RETRAIN_THRESHOLD = 0.20
    PERFORMANCE_RETRAIN_THRESHOLD_PCT = 0.05  # 5% KPI drop

    def run_daily_check(self, tenant_id: str, use_case: str):
        # Load reference dataset (training distribution)
        reference = self._load_reference_data(tenant_id, use_case)

        # Load current production data (last 7 days of scored transactions)
        current = self._load_production_data(tenant_id, use_case, days=7)

        # Data drift report (Evidently)
        report = Report(metrics=[
            DataDriftPreset(),
            DatasetDriftMetric(),
        ])
        report.run(reference_data=reference, current_data=current)
        report_dict = report.as_dict()

        # Extract PSI per feature
        drift_results = {}
        for feature_data in report_dict["metrics"][0]["result"]["drift_by_columns"].values():
            feature_name = feature_data["column_name"]
            psi = feature_data.get("stattest_threshold", 0)
            drift_results[feature_name] = psi

        # Check retrain trigger
        max_psi = max(drift_results.values())
        drifted_features = [f for f, p in drift_results.items() if p > self.PSI_RETRAIN_THRESHOLD]

        if drifted_features:
            self._trigger_retraining(
                tenant_id   = tenant_id,
                use_case    = use_case,
                reason      = f"Feature drift PSI > {self.PSI_RETRAIN_THRESHOLD}: {drifted_features}",
                max_psi     = max_psi,
            )

        # Log to Azure ML
        self._log_drift_metrics(tenant_id, use_case, drift_results, report)

    def _trigger_retraining(self, tenant_id, use_case, reason, max_psi):
        """Submit a new Azure ML pipeline run for retraining."""
        from azure.ai.ml.entities import PipelineJob
        ml_client = self._get_ml_client()
        pipeline_job = ml_client.jobs.create_or_update(
            PipelineJob(
                experiment_name = f"retrain-{use_case}-{tenant_id}",
                inputs = {
                    "tenant_id":   tenant_id,
                    "trigger_reason": reason,
                    "max_psi":     max_psi,
                },
                settings = {"default_compute": "cpu-cluster-spot"},
            )
        )
        return pipeline_job.id
```

---

## 7. MLOps KPIs & SLAs

| KPI | Target | Alert Threshold | Action |
|---|---|---|---|
| Model training duration (fraud) | < 4 hours | > 6 hours | Alert MLOps team |
| Model training duration (TFT) | < 8 hours | > 12 hours | Alert MLOps team |
| Canary pass rate | > 95% | < 90% | Auto-rollback |
| IoT Edge OTA success rate | > 99% | < 95% | Alert + manual review |
| POS ONNX bundle delivery | < 24 hours | > 48 hours | Alert IT ops |
| Drift detection latency | Daily | > 48h gap | Alert MLOps |
| Auto-retrain trigger latency | < 2 hours | > 4 hours | Alert MLOps |
| Model registry signing | 100% | Any unsigned | Block deployment |
| Bias check pass rate | 100% | Any failure | Block deployment |

---

## 8. Compute Cluster Configuration

```yaml
# compute/clusters.yaml

# CPU cluster for GBM, feature engineering (spot — 80% cost saving)
cpu_cluster_spot:
  type: amlcompute
  size: Standard_D8s_v5      # 8 vCPU, 32GB RAM
  min_instances: 0            # scale to zero when idle
  max_instances: 20
  idle_seconds_before_scaledown: 300
  tier: LowPriority           # spot pricing

# GPU cluster for DL models (TFT, LSTM, YOLOv8, FraudNet)
gpu_cluster_spot:
  type: amlcompute
  size: Standard_NC6s_v3     # 6 vCPU, 112GB RAM, 1× V100
  min_instances: 0
  max_instances: 4
  idle_seconds_before_scaledown: 120
  tier: LowPriority

# Dedicated cluster for inference endpoints (not spot)
inference_cluster:
  type: amlcompute
  size: Standard_D4s_v5      # 4 vCPU, 16GB
  min_instances: 1            # always-on for latency
  max_instances: 8
  idle_seconds_before_scaledown: 600
  tier: Dedicated
```

---

## 9. MLOps Governance Checklist (per model release)

```
Pre-training:
  [ ] Data quality gate passed (Great Expectations)
  [ ] Feature store snapshot versioned
  [ ] Training data lineage recorded (Purview)
  [ ] DPIA approved (if personal data involved)

Training:
  [ ] Hyperparameter sweep completed (Bayesian)
  [ ] Experiment tracked in MLflow (all params + metrics)
  [ ] Cross-validation scores within expected range

Evaluation:
  [ ] KPI gates passed (per use case thresholds)
  [ ] Bias evaluation passed (Fairlearn)
  [ ] SHAP values computed and stored
  [ ] Model card draft complete

Registration:
  [ ] SHA-256 hash computed and stored
  [ ] CDO (or delegate) sign-off in Model Registry
  [ ] Model card published

Deployment:
  [ ] Shadow test completed (7 days)
  [ ] Canary (5%) passed (48h monitoring)
  [ ] Staged rollout 25% → 50% → 100% passed
  [ ] IoT Edge OTA confirmed (all stores in tenant)
  [ ] POS ONNX bundle confirmed delivered

Post-deployment:
  [ ] Evidently monitoring active
  [ ] Drift baseline updated
  [ ] Rollback procedure tested
  [ ] Incident runbook updated if architecture changed
```

---

## 10. Related Documents

| Document | Reference |
|---|---|
| AI/ML Platform HLD | `01_HLD/HLD-005_AI_ML_Platform.md` |
| Fraud Detection LLD | `02_LLD/LLD-004_Fraud_Detection_Service.md` |
| Demand Forecasting LLD | `02_LLD/LLD-005_Demand_Forecasting_Pipeline.md` |
| CV Self-Checkout LLD | `02_LLD/LLD-007_CV_Self_Checkout.md` |
| Model Cards | `07_MLOps/Model_Cards.md` |
| Drift Monitoring Config | `07_MLOps/Drift_Monitoring_Config.md` |
