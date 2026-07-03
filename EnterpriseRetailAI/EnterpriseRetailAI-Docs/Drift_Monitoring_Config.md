# Drift Monitoring Configuration
## EnterpriseRetailAI · Evidently AI Monitoring for All 6 AI Use Cases

---

| Document | Drift_Monitoring_Config | Version | 1.0 | Status | Approved |

---

## 1. Overview

This document defines the Evidently AI drift monitoring configuration for all six production AI models in the EnterpriseRetailAI platform. Drift monitoring runs daily per tenant and auto-triggers retraining pipelines when thresholds are breached.

### Architecture

```
Production Prediction Logs (ADLS Gen2)
    │
    ├── Azure ML Scheduled Job (daily, 06:00 UTC per tenant)
    │       │
    │       ├── Load reference dataset (training distribution baseline)
    │       ├── Load current data (last 7 days production predictions)
    │       ├── Run Evidently AI report suite
    │       │       ├── DataDriftPreset   (feature distribution shift)
    │       │       ├── TargetDriftPreset (label / prediction shift)
    │       │       └── DataQualityPreset (missing values, outliers)
    │       │
    │       ├── Extract PSI per feature
    │       ├── Compare KPI vs. production baseline
    │       └── Publish metrics → Azure ML Monitor → Grafana
    │
    ├── [PSI > threshold] → Trigger Azure ML retraining pipeline
    ├── [KPI degraded > 10%] → Auto-rollback to previous model version
    └── [Alert] → PagerDuty + MLOps Team email
```

---

## 2. Global Drift Thresholds

| Metric | Warning Threshold | Critical Threshold | Action |
|---|---|---|---|
| PSI (Population Stability Index) | > 0.10 | > 0.20 | Warning: alert; Critical: trigger retrain |
| KS Test p-value | < 0.05 | < 0.01 | Warning: monitor; Critical: alert |
| Feature missing rate | > 5% | > 10% | Warning: investigate; Critical: halt pipeline |
| Prediction drift (PSI) | > 0.10 | > 0.20 | Warning: alert; Critical: rollback + retrain |
| KPI degradation vs. baseline | > 5% | > 10% | Warning: alert; Critical: auto-rollback |

---

## 3. UC1 — Demand Forecasting Drift Config

```python
# monitoring/configs/demand_forecast_drift.py
from evidently.report import Report
from evidently.metric_preset import DataDriftPreset, TargetDriftPreset
from evidently.metrics import (
    DatasetDriftMetric,
    DataDriftTable,
    ColumnDriftMetric,
)

DEMAND_FORECAST_CONFIG = {
    "use_case": "demand_forecast",
    "model_version_pattern": "tft_v*",
    "reference_window_days": 90,
    "current_window_days": 7,
    "schedule": "0 6 * * *",            # daily at 06:00 UTC
    "retrain_trigger_psi": 0.20,
    "kpi_retrain_threshold": {
        "mape_pct": 14.0,               # retrain if MAPE > 14% on rolling 7d
        "p90_coverage": 0.85,           # retrain if P90 coverage drops below 85%
    },

    "monitored_features": [
        "units_sold",                   # primary target — most important
        "units_sold_rolling_7d",
        "units_sold_rolling_14d",
        "units_sold_rolling_30d",
        "promotion_active",
        "avg_temp_c",
        "day_of_week",
        "is_holiday",
    ],

    "feature_thresholds": {
        "units_sold":              {"psi_warning": 0.10, "psi_critical": 0.20},
        "units_sold_rolling_7d":   {"psi_warning": 0.10, "psi_critical": 0.20},
        "promotion_active":        {"psi_warning": 0.15, "psi_critical": 0.25},
        "avg_temp_c":              {"psi_warning": 0.15, "psi_critical": 0.30},
    },

    "report_metrics": [
        DataDriftPreset(drift_share=0.3),     # alert if > 30% features drifted
        TargetDriftPreset(),
        DatasetDriftMetric(),
        ColumnDriftMetric(column_name="units_sold"),
        ColumnDriftMetric(column_name="promotion_active"),
    ],

    "output": {
        "html_report_path": "adls://monitoring/demand-forecast/{tenant_id}/{date}/report.html",
        "json_metrics_path": "adls://monitoring/demand-forecast/{tenant_id}/{date}/metrics.json",
        "azure_ml_experiment": "drift-monitoring-demand-forecast",
    }
}

def build_demand_forecast_report(reference_df, current_df) -> Report:
    report = Report(metrics=DEMAND_FORECAST_CONFIG["report_metrics"])
    report.run(
        reference_data = reference_df[DEMAND_FORECAST_CONFIG["monitored_features"]],
        current_data   = current_df[DEMAND_FORECAST_CONFIG["monitored_features"]],
    )
    return report
```

---

## 4. UC2 — Fraud Detection Drift Config

```python
# monitoring/configs/fraud_detection_drift.py

FRAUD_DETECTION_CONFIG = {
    "use_case": "fraud_detection",
    "model_version_pattern": "fraud-detect-v*",
    "reference_window_days": 30,        # shorter window — fraud patterns shift faster
    "current_window_days": 7,
    "schedule": "0 5 * * *",            # daily at 05:00 UTC
    "retrain_trigger_psi": 0.20,
    "kpi_retrain_threshold": {
        "tpr_at_fpr_02": 0.90,          # retrain if TPR drops below 90%
        "fpr_at_tpr_94": 0.03,          # retrain if FPR exceeds 3%
        "auc": 0.97,                    # retrain if AUC drops below 0.97
    },

    "monitored_features": [
        "amount_gbp",
        "discount_pct",
        "hour_of_day",
        "day_of_week",
        "card_bin_country_mismatch",
        "card_type_encoded",
        "pos_error_rate_1h",
        "cashier_tx_count_1h",
        "offline_mode_flag",
        "high_value_item_flag",
        "split_tender_flag",
        "is_new_card_at_store",
    ],

    "feature_thresholds": {
        # Monetary features — tighter PSI as fraud amounts shift
        "amount_gbp":           {"psi_warning": 0.10, "psi_critical": 0.20},
        "discount_pct":         {"psi_warning": 0.10, "psi_critical": 0.20},
        # Card features — key fraud signals
        "card_bin_country_mismatch": {"psi_warning": 0.08, "psi_critical": 0.15},
        "card_type_encoded":    {"psi_warning": 0.10, "psi_critical": 0.20},
        # Operational features
        "offline_mode_flag":    {"psi_warning": 0.15, "psi_critical": 0.25},
    },

    "label_drift_monitoring": {
        "enabled": True,
        "label_column": "is_fraud",
        "expected_fraud_rate_range": [0.001, 0.010],  # 0.1% – 1.0%
        "alert_if_outside_range": True,
    },

    "report_metrics": [
        DataDriftPreset(drift_share=0.25),    # alert if > 25% features drifted
        TargetDriftPreset(),
        DatasetDriftMetric(),
        ColumnDriftMetric(column_name="amount_gbp"),
        ColumnDriftMetric(column_name="card_bin_country_mismatch"),
        ColumnDriftMetric(column_name="offline_mode_flag"),
    ],

    "output": {
        "html_report_path": "adls://monitoring/fraud-detection/{tenant_id}/{date}/report.html",
        "json_metrics_path": "adls://monitoring/fraud-detection/{tenant_id}/{date}/metrics.json",
        "azure_ml_experiment": "drift-monitoring-fraud-detection",
        "sentinel_alert_on_critical": True,   # forward critical drift to Azure Sentinel
    }
}
```

---

## 5. UC3 — Personalisation Drift Config

```python
# monitoring/configs/personalisation_drift.py

PERSONALISATION_CONFIG = {
    "use_case": "personalisation",
    "model_version_pattern": "bandit_v*",
    "reference_window_days": 30,
    "current_window_days": 7,
    "schedule": "0 7 * * *",            # daily at 07:00 UTC
    "retrain_trigger_psi": 0.20,
    "kpi_retrain_threshold": {
        "basket_lift_pct": 5.0,         # retrain if lift drops below 5% (vs. target 8%+)
        "promo_redemption_rate": 0.20,  # retrain if redemption drops below 20%
    },

    "monitored_features": [
        "basket_total_gbp",
        "category_count",
        "is_loyalty_member",
        "hour_of_day",
        "day_of_week",
        "weather_code",
    ],

    "bandit_performance_monitoring": {
        "enabled": True,
        "reward_column": "promo_redeemed",
        "expected_explore_rate": 0.05,        # epsilon = 5%
        "min_impressions_per_variant": 100,   # before evaluating
        "ab_test_significance": 0.05,
    },

    "consent_monitoring": {
        "enabled": True,
        "alert_if_personalised_rate_below": 0.30,  # < 30% personalised → consent issue
    },

    "report_metrics": [
        DataDriftPreset(drift_share=0.30),
        TargetDriftPreset(),
        DatasetDriftMetric(),
        ColumnDriftMetric(column_name="basket_total_gbp"),
        ColumnDriftMetric(column_name="is_loyalty_member"),
    ],
}
```

---

## 6. UC4 — CV Self-Checkout Drift Config

```python
# monitoring/configs/cv_self_checkout_drift.py

CV_SELF_CHECKOUT_CONFIG = {
    "use_case": "cv_self_checkout",
    "model_version_pattern": "yolov8n_v*",
    "reference_window_days": 30,
    "current_window_days": 7,
    "schedule": "0 8 * * *",            # daily at 08:00 UTC
    "retrain_trigger": {
        "map50_drop_threshold": 0.975,  # retrain if mAP50 drops below 97.5% (gate: 98.5%)
        "false_accept_rate_threshold": 0.002,  # retrain if false accept > 0.2%
        "new_sku_classes_added": True,  # always retrain when new SKUs added
    },

    # CV models use prediction outcome monitoring (no raw feature drift)
    "prediction_monitoring": {
        "enabled": True,
        "metrics": [
            "confidence_score_distribution",  # drift in confidence histograms
            "class_prediction_distribution",  # shift in detected SKU class frequencies
            "attendant_intervention_rate",     # > 5% interventions → model degraded
            "auto_add_rate",                   # < 85% auto-add → confidence degraded
        ],
        "attendant_rate_alert_threshold": 0.08,   # 8% attendant calls = critical
        "auto_add_rate_warning_threshold": 0.88,  # < 88% = warning
        "auto_add_rate_critical_threshold": 0.82, # < 82% = critical + retrain
    },

    # Triggered by new SKU batch uploads, not time-based
    "event_triggered_retrain": {
        "trigger": "new_sku_image_batch_uploaded",
        "min_new_skus": 10,             # retrain when 10+ new SKUs added
        "pipeline": "cv_self_checkout_pipeline",
    },

    "output": {
        "html_report_path": "adls://monitoring/cv-self-checkout/{tenant_id}/{date}/report.html",
        "json_metrics_path": "adls://monitoring/cv-self-checkout/{tenant_id}/{date}/metrics.json",
    }
}
```

---

## 7. UC5 — NLP Store Assistant Drift Config

```python
# monitoring/configs/nlp_assistant_drift.py

NLP_ASSISTANT_CONFIG = {
    "use_case": "nlp_assistant",
    "model_version_pattern": "gpt-4o-*",
    "reference_window_days": 30,
    "current_window_days": 7,
    "schedule": "0 9 * * *",            # daily at 09:00 UTC

    # NLP uses outcome and usage monitoring (not raw feature PSI)
    "outcome_monitoring": {
        "enabled": True,
        "metrics": [
            "intent_classification_accuracy",  # sample labelled by QA team
            "user_satisfaction_score",         # thumbs up/down feedback
            "content_safety_filter_rate",      # % responses filtered
            "fallback_rate",                   # % queries triggering safe fallback
            "session_completion_rate",         # % sessions where query resolved
        ],
        "thresholds": {
            "intent_accuracy_warning":         0.88,   # < 88% = warning (target: 92%)
            "intent_accuracy_critical":        0.82,   # < 82% = critical + alert
            "safety_filter_rate_warning":      0.02,   # > 2% filtered = warning
            "safety_filter_rate_critical":     0.05,   # > 5% filtered = critical
            "fallback_rate_warning":           0.05,   # > 5% = warning
            "session_completion_warning":      0.80,   # < 80% = warning
        },
    },

    "knowledge_base_staleness_monitoring": {
        "enabled": True,
        "max_kb_age_hours": 26,         # alert if KB not refreshed within 26h
        "alert_on_stale_kb": True,
    },

    "language_performance_monitoring": {
        "enabled": True,
        "track_languages": ["en", "hi", "de", "fr", "zh", "ar"],
        "min_accuracy_per_language": 0.80,
    },

    # KB refresh is nightly — no model retrain trigger
    # GPT-4o is managed by Azure OpenAI (no tenant-side retrain)
    "retrain_action": "refresh_kb_embeddings",  # not model retrain

    "output": {
        "html_report_path": "adls://monitoring/nlp-assistant/{tenant_id}/{date}/report.html",
        "json_metrics_path": "adls://monitoring/nlp-assistant/{tenant_id}/{date}/metrics.json",
    }
}
```

---

## 8. UC6 — Predictive Maintenance Drift Config

```python
# monitoring/configs/predictive_maintenance_drift.py

PREDICTIVE_MAINTENANCE_CONFIG = {
    "use_case": "predictive_maintenance",
    "model_version_pattern": "pred-maint-v*",
    "reference_window_days": 30,
    "current_window_days": 7,
    "schedule": "0 4 * * *",            # daily at 04:00 UTC (before business hours)
    "retrain_trigger_psi": 0.20,
    "kpi_retrain_threshold": {
        "recall_at_72h": 0.60,          # retrain if recall drops below 60%
        "false_positive_rate": 0.25,    # retrain if FPR exceeds 25%
        "avg_lead_time_hours": 36.0,    # retrain if lead time drops below 36h
    },

    "monitored_features": [
        "cpu_usage_mean",
        "cpu_temp_max",
        "memory_used_max",
        "disk_free_min",
        "printer_roller_cycles",
        "scanner_error_rate",
        "card_reader_fail_rate",
        "touch_response_max",
        "latency_mean",
        "packet_loss_mean",
        "offline_events",
        "tx_error_rate",
        "sync_queue_max",
        "uptime_hours",
    ],

    "feature_thresholds": {
        "cpu_usage_mean":       {"psi_warning": 0.10, "psi_critical": 0.20},
        "cpu_temp_max":         {"psi_warning": 0.10, "psi_critical": 0.20},
        "scanner_error_rate":   {"psi_warning": 0.12, "psi_critical": 0.25},
        "printer_roller_cycles":{"psi_warning": 0.15, "psi_critical": 0.30},
        "latency_mean":         {"psi_warning": 0.10, "psi_critical": 0.20},
        "offline_events":       {"psi_warning": 0.15, "psi_critical": 0.25},
    },

    "device_fleet_monitoring": {
        "enabled": True,
        "alert_if_new_device_model_pct_above": 0.10,  # > 10% new device models = retrain
        "alert_if_firmware_version_drift": True,
    },

    "itsm_correlation": {
        "enabled": True,
        "servicenow_instance": "retailai.service-now.com",
        "verify_predictions_against_incidents": True,
        "lookback_days": 30,
        "min_incidents_for_evaluation": 5,
    },

    "report_metrics": [
        DataDriftPreset(drift_share=0.25),
        DatasetDriftMetric(),
        ColumnDriftMetric(column_name="cpu_temp_max"),
        ColumnDriftMetric(column_name="scanner_error_rate"),
        ColumnDriftMetric(column_name="printer_roller_cycles"),
        ColumnDriftMetric(column_name="offline_events"),
    ],

    "output": {
        "html_report_path": "adls://monitoring/predictive-maintenance/{tenant_id}/{date}/report.html",
        "json_metrics_path": "adls://monitoring/predictive-maintenance/{tenant_id}/{date}/metrics.json",
        "azure_ml_experiment": "drift-monitoring-predictive-maintenance",
    }
}
```

---

## 9. Orchestration: Daily Drift Monitor Runner

```python
# monitoring/drift_runner.py
"""
Azure ML Scheduled Job — runs daily at 04:00 UTC.
Iterates all active tenants × all use cases.
"""
import asyncio
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential
from evidently.report import Report

DRIFT_CONFIGS = {
    "demand_forecast":        DEMAND_FORECAST_CONFIG,
    "fraud_detection":        FRAUD_DETECTION_CONFIG,
    "personalisation":        PERSONALISATION_CONFIG,
    "cv_self_checkout":       CV_SELF_CHECKOUT_CONFIG,
    "nlp_assistant":          NLP_ASSISTANT_CONFIG,
    "predictive_maintenance":  PREDICTIVE_MAINTENANCE_CONFIG,
}

async def run_drift_check(tenant_id: str, use_case: str, config: dict):
    try:
        # 1. Load reference data (training baseline snapshot)
        reference = load_reference_data(tenant_id, use_case,
                                        days=config["reference_window_days"])

        # 2. Load current production predictions
        current = load_production_data(tenant_id, use_case,
                                       days=config["current_window_days"])

        if len(current) < 100:
            log.warning(f"Insufficient data for {tenant_id}/{use_case} — skipping")
            return

        # 3. Run Evidently report
        report = Report(metrics=config.get("report_metrics", [
            DataDriftPreset(), DatasetDriftMetric()
        ]))
        report.run(reference_data=reference, current_data=current)
        result = report.as_dict()

        # 4. Extract PSI per feature
        drift_results = extract_psi_results(result)
        max_psi = max(drift_results.values()) if drift_results else 0

        # 5. Log metrics to Azure ML
        log_drift_metrics(tenant_id, use_case, drift_results, config)

        # 6. Save HTML report to ADLS
        report.save_html(config["output"]["html_report_path"].format(
            tenant_id=tenant_id, date=today_str()
        ))

        # 7. Trigger retraining if threshold exceeded
        drifted = [f for f, psi in drift_results.items()
                   if psi > config.get("retrain_trigger_psi", 0.20)]

        if drifted:
            log.warning(f"DRIFT DETECTED: {tenant_id}/{use_case} — features: {drifted}")
            trigger_retraining(
                tenant_id=tenant_id,
                use_case=use_case,
                reason=f"Feature drift PSI>{config['retrain_trigger_psi']}: {drifted}",
                max_psi=max_psi,
            )

        # 8. Check KPI degradation
        check_kpi_degradation(tenant_id, use_case, config)

    except Exception as e:
        log.error(f"Drift check failed for {tenant_id}/{use_case}: {e}")
        send_alert(f"Drift monitoring error: {tenant_id}/{use_case}", str(e))


def trigger_retraining(tenant_id: str, use_case: str, reason: str, max_psi: float):
    """Submit Azure ML pipeline job for retraining."""
    ml_client = MLClient(DefaultAzureCredential(), SUBSCRIPTION_ID, RG, WORKSPACE)

    pipeline_map = {
        "demand_forecast":       "demand_forecast_tft_pipeline",
        "fraud_detection":       "fraud_detection_lgbm_pipeline",
        "personalisation":       "personalisation_collab_filter_pipeline",
        "cv_self_checkout":      "cv_self_checkout_pipeline",
        "nlp_assistant":         "nlp_kb_refresh_pipeline",
        "predictive_maintenance": "predictive_maintenance_lstm_pipeline",
    }

    job = ml_client.jobs.create_or_update(
        PipelineJob(
            experiment_name=f"drift-retrain-{use_case}-{tenant_id}",
            inputs={
                "tenant_id":       tenant_id,
                "trigger_reason":  reason,
                "max_psi":         str(max_psi),
            },
        )
    )
    log.info(f"Retraining triggered: {job.id}")


def check_kpi_degradation(tenant_id: str, use_case: str, config: dict):
    """Compare current KPIs against production baseline; rollback if critical drop."""
    thresholds = config.get("kpi_retrain_threshold", {})
    current_kpis = get_current_kpis(tenant_id, use_case)

    for kpi_name, threshold in thresholds.items():
        current_value = current_kpis.get(kpi_name)
        if current_value is None:
            continue

        # For metrics where higher = better (TPR, lift, coverage, recall)
        # For metrics where lower = better (MAPE, FPR, false_positive_rate)
        higher_is_better = kpi_name not in ["mape_pct", "fpr_at_tpr_94",
                                              "false_positive_rate"]
        degraded = (current_value < threshold if higher_is_better
                    else current_value > threshold)

        if degraded:
            log.critical(f"KPI DEGRADED: {tenant_id}/{use_case} "
                         f"{kpi_name}={current_value} vs threshold={threshold}")
            # Auto-rollback to previous production model
            rollback_model(tenant_id, use_case)
            send_pagerduty_alert(
                severity="CRITICAL",
                title=f"Auto-rollback: {use_case} KPI degraded for {tenant_id}",
                body=f"{kpi_name}: {current_value} (threshold: {threshold})",
            )
```

---

## 10. Grafana Dashboard Metrics

All drift monitoring metrics are published to Azure Monitor and surfaced in Grafana:

| Metric Name | Type | Description |
|---|---|---|
| `drift.psi.{feature}` | Gauge | PSI score per feature per use case |
| `drift.dataset.drift_detected` | Gauge | 1 = drift detected, 0 = stable |
| `drift.dataset.drifted_features_pct` | Gauge | Percentage of features drifted |
| `drift.kpi.current_value` | Gauge | Current KPI value per use case |
| `drift.kpi.baseline_value` | Gauge | Baseline KPI value at last release |
| `drift.kpi.degradation_pct` | Gauge | % degradation vs. baseline |
| `drift.retrain.triggered_total` | Counter | Cumulative retrain triggers |
| `drift.rollback.triggered_total` | Counter | Cumulative auto-rollbacks |
| `drift.check.duration_seconds` | Histogram | Time taken for drift check |
| `drift.data.reference_rows` | Gauge | Rows in reference dataset |
| `drift.data.current_rows` | Gauge | Rows in current production dataset |

### Grafana Alert Rules

```yaml
# grafana/alerts/drift_alerts.yaml

groups:
  - name: drift_monitoring
    rules:
      - alert: FeatureDriftCritical
        expr: drift_psi_score > 0.20
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Critical feature drift detected"
          description: "PSI {{ $value }} exceeds critical threshold 0.20 for {{ $labels.feature }}"

      - alert: ModelKPIDegraded
        expr: drift_kpi_degradation_pct > 10
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Model KPI critically degraded"
          description: "{{ $labels.use_case }} KPI degraded {{ $value }}% vs baseline"

      - alert: DriftMonitoringGap
        expr: time() - drift_check_last_run_timestamp > 86400  # 24h
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Drift monitoring not running"
          description: "{{ $labels.tenant_id }}/{{ $labels.use_case }} drift check overdue"

      - alert: AutoRollbackTriggered
        expr: increase(drift_rollback_triggered_total[1h]) > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Model auto-rollback triggered"
          description: "{{ $labels.use_case }} for tenant {{ $labels.tenant_id }} auto-rolled back"
```

---

## 11. Notification Routing

| Event | Channel | Recipients |
|---|---|---|
| PSI warning (0.10–0.20) | Azure Monitor Alert → Email | MLOps team |
| PSI critical (> 0.20) + retrain triggered | PagerDuty P3 + Email | MLOps team + CDO |
| KPI degraded > 5% | Azure Monitor Alert → Email + Slack | MLOps team |
| Auto-rollback triggered | PagerDuty P1 + Email + Slack | MLOps team + CDO + CTO |
| Drift monitoring gap > 24h | PagerDuty P2 | MLOps team |
| Bias threshold exceeded | Email + ARB notification | CDO + DPO + ARB |

---

## 12. Related Documents

| Document | Reference |
|---|---|
| AI/ML Platform HLD | `01_HLD/HLD-005_AI_ML_Platform.md` |
| MLOps Pipeline LLD | `02_LLD/LLD-015_MLOps_Pipeline_Design.md` |
| MLOps Pipeline Config | `07_MLOps/MLOps_Pipeline_Config.md` |
| Model Cards | `07_MLOps/Model_Cards.md` |
| Fraud Detection LLD | `02_LLD/LLD-004_Fraud_Detection_Service.md` |
| Demand Forecasting LLD | `02_LLD/LLD-005_Demand_Forecasting_Pipeline.md` |

