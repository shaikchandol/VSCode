# MLOps Pipeline Configuration
## EnterpriseRetailAI · Azure ML Pipeline YAML Configs for All 6 AI Use Cases

---

| Document | MLOps_Pipeline_Config | Version | 1.0 | Status | Approved | Date | June 2026 |

---

## 1. Overview

This document contains the Azure ML pipeline YAML configurations for all six AI use cases. Each pipeline is tenant-parameterised and executed via Azure ML SDK v2 or scheduled via Azure ML job triggers.

---

## 2. UC1 — Demand Forecasting Pipeline

```yaml
# azure_ml/pipelines/demand_forecast_pipeline.yaml
$schema: https://azuremlschemas.azureedge.net/latest/pipelineJob.schema.json
type: pipeline

display_name: demand_forecast_tft_pipeline
description: Daily incremental + weekly full retrain of TFT demand forecasting model

settings:
  default_compute: gpu-cluster-spot
  default_datastore: workspaceblobstore
  continue_on_step_failure: false

inputs:
  tenant_id:
    type: string
  run_mode:
    type: string
    default: incremental       # incremental | full_retrain
  lookback_days:
    type: integer
    default: 90
  forecast_horizon_days:
    type: integer
    default: 30

jobs:
  data_ingestion:
    type: command
    component: azureml:sales_data_ingester:1.3.0
    inputs:
      tenant_id: ${{inputs.tenant_id}}
      lookback_days: ${{inputs.lookback_days}}
      source_container: azureml://datastores/datalake/paths/${{inputs.tenant_id}}/raw/transactions/
    outputs:
      raw_sales_data:
        type: uri_folder

  feature_engineering:
    type: command
    component: azureml:forecast_feature_engineer:2.1.0
    compute: cpu-cluster-spot
    inputs:
      raw_sales_data: ${{parent.jobs.data_ingestion.outputs.raw_sales_data}}
      tenant_id: ${{inputs.tenant_id}}
      calendar_data: azureml:global_calendar_dataset:latest
      weather_data: azureml:weather_forecast_dataset:latest
    outputs:
      feature_set:
        type: mltable

  data_quality_gate:
    type: command
    component: azureml:great_expectations_validator:1.0.0
    inputs:
      feature_set: ${{parent.jobs.feature_engineering.outputs.feature_set}}
      expectation_suite: azureml:forecast_expectations:2.0
      max_missing_pct: 5.0
    outputs:
      validated_data:
        type: mltable

  tft_training:
    type: command
    component: azureml:tft_trainer:3.0.0
    compute: gpu-cluster-spot
    inputs:
      validated_data: ${{parent.jobs.data_quality_gate.outputs.validated_data}}
      tenant_id: ${{inputs.tenant_id}}
      run_mode: ${{inputs.run_mode}}
      max_epochs: 50
      early_stopping_patience: 5
      hidden_size: 64
      lstm_layers: 2
      attention_heads: 4
    outputs:
      model_artifacts:
        type: uri_folder
      training_metrics:
        type: uri_file

  model_evaluation:
    type: command
    component: azureml:forecast_evaluator:1.2.0
    inputs:
      model_artifacts: ${{parent.jobs.tft_training.outputs.model_artifacts}}
      validated_data: ${{parent.jobs.data_quality_gate.outputs.validated_data}}
      kpi_gates:
        mape_threshold_pct: 12.0
        p90_coverage_threshold: 0.88
    outputs:
      eval_report:
        type: uri_file

  model_registration:
    type: command
    component: azureml:model_registrar:1.0.0
    inputs:
      model_artifacts: ${{parent.jobs.tft_training.outputs.model_artifacts}}
      eval_report: ${{parent.jobs.model_evaluation.outputs.eval_report}}
      tenant_id: ${{inputs.tenant_id}}
      model_name: demand-forecast
      model_format: PYTORCH
      deployment_targets: ["cloud"]
    outputs:
      registered_model_id:
        type: uri_file

  edge_export:
    type: command
    component: azureml:tft_lite_exporter:1.0.0
    inputs:
      model_artifacts: ${{parent.jobs.tft_training.outputs.model_artifacts}}
      target_opset: 17
      quantize: true
    outputs:
      onnx_lite_bundle:
        type: uri_folder

# Schedules
schedules:
  daily_incremental:
    trigger:
      type: recurrence
      frequency: day
      interval: 1
      start_time: "2026-06-01T02:00:00"
      time_zone: UTC
    inputs:
      run_mode: incremental

  weekly_full_retrain:
    trigger:
      type: recurrence
      frequency: week
      interval: 1
      week_days: [Sunday]
      start_time: "2026-06-01T00:00:00"
    inputs:
      run_mode: full_retrain
      lookback_days: 730
```

---

## 3. UC2 — Fraud Detection Pipeline

```yaml
# azure_ml/pipelines/fraud_detection_pipeline.yaml
$schema: https://azuremlschemas.azureedge.net/latest/pipelineJob.schema.json
type: pipeline

display_name: fraud_detection_lgbm_pipeline
description: Weekly fraud model retraining + ONNX export + IoT Hub deployment

settings:
  default_compute: cpu-cluster-spot
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
    component: azureml:fraud_data_validator:1.1.0
    inputs:
      raw_data:
        type: uri_folder
        path: azureml://datastores/datalake/paths/${{inputs.tenant_id}}/ml-training/fraud-detection/
      max_missing_pct: 5.0

  feature_engineering:
    type: command
    component: azureml:fraud_feature_engineer:1.2.0
    inputs:
      validated_data: ${{parent.jobs.data_validation.outputs.validated_data}}
      tenant_id: ${{inputs.tenant_id}}
      window_days: ${{inputs.training_window_days}}
      feature_version: "2.1"

  model_training:
    type: command
    component: azureml:fraud_lgbm_trainer:2.0.0
    inputs:
      feature_set: ${{parent.jobs.feature_engineering.outputs.feature_set}}
      tenant_id: ${{inputs.tenant_id}}
      min_fraud_samples: ${{inputs.min_fraud_samples}}
      num_leaves: 63
      max_depth: 8
      learning_rate: 0.05
      n_estimators: 500

  bias_evaluation:
    type: command
    component: azureml:fairlearn_evaluator:1.0.0
    inputs:
      model_artifacts: ${{parent.jobs.model_training.outputs.model_artifacts}}
      feature_set: ${{parent.jobs.feature_engineering.outputs.feature_set}}
      protected_features: ["card_bin_country_mismatch", "card_type_encoded"]
      max_tpr_disparity: 0.05

  onnx_export:
    type: command
    component: azureml:onnx_exporter:1.1.0
    inputs:
      model_artifacts: ${{parent.jobs.model_training.outputs.model_artifacts}}
      target_opset: 17
      quantize: true
      quantize_type: QInt8
      sign_bundle: true

  model_registration:
    type: command
    component: azureml:model_registrar:1.0.0
    inputs:
      onnx_bundle: ${{parent.jobs.onnx_export.outputs.onnx_bundle}}
      training_metrics: ${{parent.jobs.model_training.outputs.training_metrics}}
      bias_report: ${{parent.jobs.bias_evaluation.outputs.bias_report}}
      tenant_id: ${{inputs.tenant_id}}
      model_name: fraud-detection
      deployment_targets: ["cloud", "edge", "pos"]
      kpi_gates:
        tpr_at_fpr_02: 0.94
        fpr_at_tpr_94: 0.02
        auc: 0.98
        max_tpr_disparity: 0.05

schedules:
  weekly_retrain:
    trigger:
      type: recurrence
      frequency: week
      interval: 1
      week_days: [Saturday]
      start_time: "2026-06-01T01:00:00"
```

---

## 4. UC3 — Personalisation Pipeline

```yaml
# azure_ml/pipelines/personalisation_pipeline.yaml
$schema: https://azuremlschemas.azureedge.net/latest/pipelineJob.schema.json
type: pipeline

display_name: personalisation_collab_filter_pipeline
description: Weekly collaborative filtering retrain + bandit warm-start

inputs:
  tenant_id:
    type: string
  interaction_window_days:
    type: integer
    default: 90

jobs:
  interaction_data_prep:
    type: command
    component: azureml:interaction_data_preparer:1.0.0
    inputs:
      tenant_id: ${{inputs.tenant_id}}
      window_days: ${{inputs.interaction_window_days}}
      min_interactions_per_customer: 3

  embedding_training:
    type: command
    component: azureml:customer_embedder:1.0.0
    compute: cpu-cluster-spot
    inputs:
      interaction_data: ${{parent.jobs.interaction_data_prep.outputs.interaction_data}}
      embedding_dim: 384
      model_name: all-MiniLM-L6-v2

  collaborative_filter_training:
    type: command
    component: azureml:als_trainer:1.0.0
    inputs:
      interaction_data: ${{parent.jobs.interaction_data_prep.outputs.interaction_data}}
      factors: 128
      iterations: 20
      regularization: 0.01

  bandit_warm_start:
    type: command
    component: azureml:vw_bandit_trainer:1.0.0
    inputs:
      cf_model: ${{parent.jobs.collaborative_filter_training.outputs.model}}
      historical_outcomes: ${{parent.jobs.interaction_data_prep.outputs.outcome_data}}
      epsilon: 0.05

  ab_test_config:
    type: command
    component: azureml:ab_test_configurator:1.0.0
    inputs:
      model_artifacts: ${{parent.jobs.bandit_warm_start.outputs.model}}
      control_weight: 50
      treatment_weight: 50
      min_sample_size: 1000

schedules:
  weekly_retrain:
    trigger:
      type: recurrence
      frequency: week
      interval: 1
      week_days: [Friday]
```

---

## 5. UC4 — Computer Vision Pipeline

```yaml
# azure_ml/pipelines/cv_self_checkout_pipeline.yaml
$schema: https://azuremlschemas.azureedge.net/latest/pipelineJob.schema.json
type: pipeline

display_name: cv_item_recognition_pipeline
description: Per-tenant YOLOv8 fine-tuning on new SKU image batches

inputs:
  tenant_id:
    type: string
  new_skus_only:
    type: boolean
    default: true

jobs:
  image_dataset_prep:
    type: command
    component: azureml:cv_dataset_preparer:1.0.0
    inputs:
      tenant_id: ${{inputs.tenant_id}}
      new_skus_only: ${{inputs.new_skus_only}}
      min_images_per_class: 200
      train_split: 0.8
      val_split: 0.1
      test_split: 0.1

  data_augmentation:
    type: command
    component: azureml:image_augmentor:1.0.0
    inputs:
      dataset: ${{parent.jobs.image_dataset_prep.outputs.dataset}}
      flip_lr: 0.5
      rotation_degrees: 15
      brightness_factor: 0.2
      hsv_augmentation: true

  yolov8_finetuning:
    type: command
    component: azureml:yolov8_trainer:1.8.0
    compute: gpu-cluster-spot
    inputs:
      dataset: ${{parent.jobs.data_augmentation.outputs.augmented_dataset}}
      base_model: azureml:yolov8n_coco_pretrained:latest
      epochs: 100
      imgsz: 640
      batch: 16
      patience: 20

  model_evaluation:
    type: command
    component: azureml:cv_model_evaluator:1.0.0
    inputs:
      model: ${{parent.jobs.yolov8_finetuning.outputs.best_model}}
      test_dataset: ${{parent.jobs.image_dataset_prep.outputs.test_dataset}}
      kpi_gates:
        map50_threshold: 0.985
        false_accept_rate_threshold: 0.001

  onnx_export_quantise:
    type: command
    component: azureml:yolov8_onnx_exporter:1.0.0
    inputs:
      model: ${{parent.jobs.yolov8_finetuning.outputs.best_model}}
      opset: 17
      quantize_int8: true
      calibration_samples: 500

  iot_edge_deployment:
    type: command
    component: azureml:iot_edge_deployer:1.0.0
    inputs:
      onnx_bundle: ${{parent.jobs.onnx_export_quantise.outputs.onnx_bundle}}
      tenant_id: ${{inputs.tenant_id}}
      module_name: cv-item-recognition
      deployment_mode: canary
      canary_pct: 10
```

---

## 6. UC5 — NLP Knowledge Base Refresh Pipeline

```yaml
# azure_ml/pipelines/nlp_kb_refresh_pipeline.yaml
$schema: https://azuremlschemas.azureedge.net/latest/pipelineJob.schema.json
type: pipeline

display_name: nlp_knowledge_base_refresh
description: Nightly refresh of Azure AI Search knowledge base for NLP store assistant

inputs:
  tenant_id:
    type: string
  refresh_mode:
    type: string
    default: delta              # delta | full

jobs:
  kb_content_sync:
    type: command
    component: azureml:kb_content_syncer:1.0.0
    inputs:
      tenant_id: ${{inputs.tenant_id}}
      refresh_mode: ${{inputs.refresh_mode}}
      sources:
        - type: product_catalogue
          source: cosmos_db
        - type: promotions
          source: tenant_sql
        - type: store_policies
          source: sharepoint
        - type: faqs
          source: blob_storage

  embedding_generation:
    type: command
    component: azureml:doc_embedder:1.0.0
    inputs:
      documents: ${{parent.jobs.kb_content_sync.outputs.documents}}
      embedding_model: text-embedding-ada-002
      batch_size: 100
      chunk_size: 512
      chunk_overlap: 50

  search_index_update:
    type: command
    component: azureml:ai_search_indexer:1.0.0
    inputs:
      embeddings: ${{parent.jobs.embedding_generation.outputs.embeddings}}
      tenant_id: ${{inputs.tenant_id}}
      index_name: retailai-kb-${{inputs.tenant_id}}
      merge_mode: ${{inputs.refresh_mode}}

  edge_kb_cache_push:
    type: command
    component: azureml:edge_kb_pusher:1.0.0
    inputs:
      tenant_id: ${{inputs.tenant_id}}
      cache_format: jsonl
      categories: ["products", "promotions", "policies", "faqs"]
      iot_hub_deployment: true

schedules:
  nightly_delta:
    trigger:
      type: recurrence
      frequency: day
      interval: 1
      start_time: "2026-06-01T03:00:00"
    inputs:
      refresh_mode: delta

  weekly_full:
    trigger:
      type: recurrence
      frequency: week
      interval: 1
      week_days: [Sunday]
      start_time: "2026-06-01T04:00:00"
    inputs:
      refresh_mode: full
```

---

## 7. UC6 — Predictive Maintenance Pipeline

```yaml
# azure_ml/pipelines/predictive_maintenance_pipeline.yaml
$schema: https://azuremlschemas.azureedge.net/latest/pipelineJob.schema.json
type: pipeline

display_name: predictive_maintenance_lstm_pipeline
description: Weekly retraining of Isolation Forest + LSTM for POS hardware failure prediction

inputs:
  tenant_id:
    type: string
  telemetry_window_days:
    type: integer
    default: 90
  device_type:
    type: string
    default: ALL                # ALL | WINDOWS_POS | ANDROID_POS | KIOSK

jobs:
  telemetry_ingestion:
    type: command
    component: azureml:telemetry_ingester:1.0.0
    inputs:
      tenant_id: ${{inputs.tenant_id}}
      window_days: ${{inputs.telemetry_window_days}}
      device_type: ${{inputs.device_type}}
      source: azureml://datastores/datalake/paths/${{inputs.tenant_id}}/raw/telemetry/

  feature_engineering:
    type: command
    component: azureml:maintenance_feature_engineer:1.0.0
    inputs:
      raw_telemetry: ${{parent.jobs.telemetry_ingestion.outputs.raw_telemetry}}
      window_sizes: [1, 6, 24]           # 1h, 6h, 24h rolling windows
      failure_label_lookahead_hours: 72

  isolation_forest_training:
    type: command
    component: azureml:isolation_forest_trainer:1.0.0
    compute: cpu-cluster-spot
    inputs:
      feature_set: ${{parent.jobs.feature_engineering.outputs.feature_set}}
      device_type: ${{inputs.device_type}}
      n_estimators: 200
      contamination: 0.02
    outputs:
      model_artifacts:
        type: uri_folder

  lstm_training:
    type: command
    component: azureml:maintenance_lstm_trainer:1.0.0
    compute: gpu-cluster-spot
    inputs:
      feature_set: ${{parent.jobs.feature_engineering.outputs.feature_set}}
      sequence_length: 24
      hidden_size: 64
      num_layers: 2
      max_epochs: 50
      output_components: 6           # 6 hardware components
    outputs:
      model_artifacts:
        type: uri_folder

  model_evaluation:
    type: command
    component: azureml:maintenance_evaluator:1.0.0
    inputs:
      isolation_forest: ${{parent.jobs.isolation_forest_training.outputs.model_artifacts}}
      lstm_model: ${{parent.jobs.lstm_training.outputs.model_artifacts}}
      test_data: ${{parent.jobs.feature_engineering.outputs.test_set}}
      kpi_gates:
        recall_at_72h: 0.70
        false_positive_rate: 0.15

  model_registration:
    type: command
    component: azureml:model_registrar:1.0.0
    inputs:
      model_artifacts: ${{parent.jobs.lstm_training.outputs.model_artifacts}}
      tenant_id: ${{inputs.tenant_id}}
      model_name: predictive-maintenance
      deployment_targets: ["cloud", "edge"]

schedules:
  weekly_retrain:
    trigger:
      type: recurrence
      frequency: week
      interval: 1
      week_days: [Saturday]
      start_time: "2026-06-01T05:00:00"
```

---

## 8. Shared Components Registry

```yaml
# Reusable pipeline components (registered in Azure ML)

components:
  - name: data_validator
    version: "1.0.0"
    type: command
    code: ./components/data_validator/
    environment: azureml:retailai-mlops-env:latest
    command: python validate.py --input ${{inputs.data}} --suite ${{inputs.suite}}

  - name: onnx_exporter
    version: "1.1.0"
    type: command
    code: ./components/onnx_exporter/
    environment: azureml:retailai-onnx-env:latest
    command: >
      python export.py
      --model ${{inputs.model_artifacts}}
      --opset ${{inputs.target_opset}}
      --quantize ${{inputs.quantize}}
      --output ${{outputs.onnx_bundle}}

  - name: model_registrar
    version: "1.0.0"
    type: command
    code: ./components/model_registrar/
    environment: azureml:retailai-mlops-env:latest
    command: >
      python register.py
      --artifacts ${{inputs.model_artifacts}}
      --tenant ${{inputs.tenant_id}}
      --name ${{inputs.model_name}}
      --gates ${{inputs.kpi_gates}}

  - name: iot_edge_deployer
    version: "1.0.0"
    type: command
    code: ./components/iot_edge_deployer/
    environment: azureml:retailai-mlops-env:latest
    command: >
      python deploy_edge.py
      --bundle ${{inputs.onnx_bundle}}
      --tenant ${{inputs.tenant_id}}
      --module ${{inputs.module_name}}
      --mode ${{inputs.deployment_mode}}
```

---

## 9. Environment Definitions

```yaml
# environments/retailai-mlops-env.yaml
name: retailai-mlops-env
version: "2.1.0"
image: mcr.microsoft.com/azureml/openmpi4.1.0-ubuntu22.04:latest
conda_file:
  name: retailai-mlops
  channels: [conda-forge, pytorch]
  dependencies:
    - python=3.11
    - pip:
      - azureml-sdk==1.55.0
      - azure-ai-ml==1.14.0
      - lightgbm==4.3.0
      - scikit-learn==1.4.0
      - pytorch-forecasting==1.0.0
      - pytorch-lightning==2.2.0
      - onnx==1.16.0
      - onnxruntime==1.17.0
      - skl2onnx==1.17.0
      - evidently==0.4.30
      - fairlearn==0.10.0
      - shap==0.45.0
      - mlflow==2.12.0
      - great-expectations==0.18.0
      - pandas==2.2.0
      - numpy==1.26.0

# environments/retailai-onnx-env.yaml
name: retailai-onnx-env
version: "1.2.0"
image: mcr.microsoft.com/azureml/openmpi4.1.0-ubuntu22.04:latest
conda_file:
  dependencies:
    - python=3.11
    - pip:
      - onnx==1.16.0
      - onnxruntime==1.17.0
      - onnxruntime-tools==1.7.0
      - onnxconverter-common==1.13.0
      - ultralytics==8.2.0      # YOLOv8
      - skl2onnx==1.17.0

# environments/retailai-gpu-env.yaml  (GPU training)
name: retailai-gpu-env
version: "1.1.0"
image: mcr.microsoft.com/azureml/pytorch-2.2-cuda12.1:latest
conda_file:
  dependencies:
    - python=3.11
    - cudatoolkit=12.1
    - pip:
      - torch==2.2.0+cu121
      - pytorch-forecasting==1.0.0
      - ultralytics==8.2.0
      - mlflow==2.12.0
```

---

## 10. Related Documents

| Document | Reference |
|---|---|
| AI/ML Platform HLD | `01_HLD/HLD-005_AI_ML_Platform.md` |
| MLOps Pipeline LLD | `02_LLD/LLD-015_MLOps_Pipeline_Design.md` |
| Model Cards | `07_MLOps/Model_Cards.md` |
| Drift Monitoring Config | `07_MLOps/Drift_Monitoring_Config.md` |
