# LLD-009 — Predictive Maintenance Service
## EnterpriseRetailAI · IoT Telemetry Schema, Anomaly Detection, Alert Service

---

| Document ID | LLD-009 | Version | 1.0 | Status | Approved | Date | June 2026 |

---

## 1. Architecture Overview

```
POS Terminal (60s telemetry heartbeat)
    │ IoT Hub MQTT/AMQP
    ▼
Azure IoT Hub → Azure Digital Twins (device model)
    │
    ├── Real-time path:
    │   Azure Stream Analytics → Anomaly Alert (< 2 min)
    │
    └── ML path:
        ADLS Gen2 (telemetry archive)
        Azure ML (LSTM failure prediction, 72h horizon)
        Azure ML Batch Endpoint → Maintenance Schedule
            │
        ServiceNow ITSM → Ticket + Dispatch technician
```

---

## 2. Telemetry Schema

```json
{
  "device_id":    "POS-STORE001-T01",
  "tenant_id":    "franchisee_042",
  "store_id":     "store_001",
  "timestamp":    "2026-06-11T10:00:00.000Z",
  "schema_ver":   "2.1",
  "system": {
    "cpu_usage_pct":       23.4,
    "cpu_temp_celsius":    52.1,
    "memory_used_mb":      1842,
    "memory_total_mb":     8192,
    "disk_free_gb":        42.1,
    "disk_read_iops":      145,
    "disk_write_iops":     23,
    "uptime_hours":        1247.5
  },
  "network": {
    "latency_to_edge_ms":  12,
    "packet_loss_pct":     0.0,
    "wifi_rssi_dbm":       -52,
    "wan_connected":       true,
    "offline_since":       null
  },
  "peripherals": {
    "printer": {
      "status":            "OK",
      "paper_low":         false,
      "head_temp_celsius": 38.2,
      "roller_cycles":     142850,
      "error_count_1h":    0
    },
    "barcode_scanner": {
      "status":            "OK",
      "reads_1h":          487,
      "failed_reads_1h":   3,
      "error_rate_pct":    0.61
    },
    "card_reader": {
      "status":            "OK",
      "reads_1h":          312,
      "failed_reads_1h":   0,
      "chip_read_fails_1h": 0,
      "contactless_fails_1h": 0
    },
    "cash_drawer": {
      "status":            "OK",
      "open_events_1h":    18
    },
    "touch_screen": {
      "status":            "OK",
      "avg_response_ms":   45,
      "unresponsive_events_1h": 0
    }
  },
  "application": {
    "transactions_1h":       87,
    "transaction_errors_1h": 0,
    "sync_queue_depth":      0,
    "last_sync_success_ts":  "2026-06-11T09:59:48Z",
    "onnx_fraud_model_ver":  "2.4.1",
    "onnx_promo_model_ver":  "1.8.0",
    "app_version":           "4.2.1"
  }
}
```

---

## 3. Feature Engineering for ML Models

```python
def build_maintenance_features(telemetry_df) -> pd.DataFrame:
    """
    Build 15 aggregate features per device per hour window.
    These feed both the Isolation Forest and LSTM models.
    """
    features = telemetry_df.groupby(["device_id", "hour_window"]).agg(
        # System
        cpu_usage_mean        = ("cpu_usage_pct", "mean"),
        cpu_temp_max          = ("cpu_temp_celsius", "max"),
        memory_used_max       = ("memory_used_mb", "max"),
        disk_free_min         = ("disk_free_gb", "min"),

        # Peripherals
        printer_roller_cycles = ("printer_roller_cycles", "last"),  # total count
        scanner_error_rate    = ("barcode_scanner_error_rate_pct", "mean"),
        card_reader_fail_rate = ("card_reader_failed_reads_1h", "sum"),
        touch_response_max    = ("touch_screen_avg_response_ms", "max"),
        touch_errors          = ("touch_screen_unresponsive_events_1h", "sum"),

        # Network
        latency_mean          = ("latency_to_edge_ms", "mean"),
        packet_loss_mean      = ("network_packet_loss_pct", "mean"),
        offline_events        = ("wan_connected", lambda x: (~x).sum()),

        # Application health
        tx_error_rate         = ("application_transaction_errors_1h", "sum"),
        sync_queue_max        = ("application_sync_queue_depth", "max"),

        # Device age
        uptime_hours          = ("system_uptime_hours", "last"),
    ).reset_index()

    return features
```

---

## 4. Isolation Forest (Real-time Anomaly Detection)

```python
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import joblib

def train_isolation_forest(
    features_df: pd.DataFrame,
    device_type: str,           # "WINDOWS_POS", "ANDROID_POS", "KIOSK"
    contamination: float = 0.02,  # expected anomaly fraction: 2%
) -> tuple:
    """
    Train per-device-type Isolation Forest.
    Deployed as IoT Edge ONNX module for real-time scoring.
    """
    feature_cols = [
        "cpu_usage_mean", "cpu_temp_max", "memory_used_max",
        "disk_free_min", "scanner_error_rate", "card_reader_fail_rate",
        "touch_response_max", "latency_mean", "packet_loss_mean",
        "offline_events", "tx_error_rate", "sync_queue_max",
    ]

    X = features_df[feature_cols].fillna(0)

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    model = IsolationForest(
        n_estimators    = 200,
        max_samples     = "auto",
        contamination   = contamination,
        max_features    = 1.0,
        bootstrap       = False,
        random_state    = 42,
        n_jobs          = -1,
    )
    model.fit(X_scaled)

    # Score: +1 = normal, -1 = anomaly
    # Convert to anomaly probability [0, 1]
    scores = model.score_samples(X_scaled)  # higher = more normal

    # Save
    joblib.dump({"model": model, "scaler": scaler, "features": feature_cols},
                f"/models/isolation_forest_{device_type}.pkl")

    return model, scaler
```

---

## 5. LSTM Failure Prediction Model

```python
import torch
import torch.nn as nn

class PredictiveMaintenanceLSTM(nn.Module):
    """
    Bi-directional LSTM for 72-hour failure prediction.
    Input: sequence of 24 hourly feature vectors (15 features each)
    Output: failure probability per component in next 72 hours
    """
    def __init__(
        self,
        input_size:   int = 15,    # feature vector size
        hidden_size:  int = 64,
        num_layers:   int = 2,
        dropout:      float = 0.2,
        output_size:  int = 6,     # 6 failure components
    ):
        super().__init__()

        self.lstm = nn.LSTM(
            input_size  = input_size,
            hidden_size = hidden_size,
            num_layers  = num_layers,
            batch_first = True,
            dropout     = dropout,
            bidirectional = True,
        )

        self.attention = nn.MultiheadAttention(
            embed_dim   = hidden_size * 2,  # bidirectional
            num_heads   = 4,
            dropout     = dropout,
            batch_first = True,
        )

        self.classifier = nn.Sequential(
            nn.Linear(hidden_size * 2, 64),
            nn.ReLU(),
            nn.Dropout(dropout),
            nn.Linear(64, output_size),
            nn.Sigmoid(),    # probability per component
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        # x: [batch, seq_len=24, input_size=15]
        lstm_out, _ = self.lstm(x)              # [batch, 24, hidden*2]

        # Self-attention over time steps
        attn_out, _ = self.attention(lstm_out, lstm_out, lstm_out)

        # Use last time step output
        out = attn_out[:, -1, :]               # [batch, hidden*2]
        return self.classifier(out)             # [batch, 6] — failure probabilities

# Output components:
# [0] thermal_printer_failure
# [1] barcode_scanner_failure
# [2] card_reader_failure
# [3] network_adapter_failure
# [4] touch_screen_failure
# [5] hardware_general_failure
```

---

## 6. Anomaly Alert Service (AKS)

```python
from azure.servicebus import ServiceBusClient, ServiceBusMessage
from dataclasses import dataclass
import pyservicenow

@dataclass
class MaintenanceAlert:
    device_id:       str
    tenant_id:       str
    store_id:        str
    alert_type:      str          # ANOMALY | PREDICTED_FAILURE
    component:       str          # printer, scanner, etc.
    severity:        str          # CRITICAL | WARNING | INFO
    confidence:      float
    predicted_in_hours: int | None
    anomaly_score:   float | None
    top_features:    dict         # feature contribution to anomaly
    recommended_action: str
    created_at:      str

class AlertService:
    SEVERITY_THRESHOLDS = {
        "CRITICAL":  0.80,    # high confidence failure
        "WARNING":   0.55,    # moderate confidence
        "INFO":      0.35,    # low confidence / monitor
    }

    def process_prediction(
        self,
        device_id: str,
        failure_probs: list[float],  # from LSTM [6 components]
        anomaly_score: float,         # from Isolation Forest
        device_context: dict,
    ) -> list[MaintenanceAlert]:
        alerts = []
        components = [
            "thermal_printer", "barcode_scanner", "card_reader",
            "network_adapter", "touch_screen", "hardware_general"
        ]

        for i, (component, prob) in enumerate(zip(components, failure_probs)):
            if prob < self.SEVERITY_THRESHOLDS["INFO"]:
                continue

            severity = (
                "CRITICAL" if prob >= self.SEVERITY_THRESHOLDS["CRITICAL"]
                else "WARNING" if prob >= self.SEVERITY_THRESHOLDS["WARNING"]
                else "INFO"
            )

            alert = MaintenanceAlert(
                device_id   = device_id,
                tenant_id   = device_context["tenant_id"],
                store_id    = device_context["store_id"],
                alert_type  = "PREDICTED_FAILURE",
                component   = component,
                severity    = severity,
                confidence  = prob,
                predicted_in_hours = 72,
                anomaly_score = anomaly_score,
                top_features = self._get_top_features(device_context, component),
                recommended_action = self._get_recommendation(component, severity),
                created_at  = datetime.utcnow().isoformat(),
            )
            alerts.append(alert)

            # Auto-create ITSM ticket for WARNING and above
            if severity in ("CRITICAL", "WARNING"):
                self._create_servicenow_ticket(alert)

        return alerts

    def _create_servicenow_ticket(self, alert: MaintenanceAlert):
        incident = {
            "short_description": (
                f"[PredMaint-{alert.severity}] {alert.component.replace('_',' ').title()} "
                f"failure predicted — {alert.device_id}"
            ),
            "description": (
                f"Device: {alert.device_id}\n"
                f"Store: {alert.store_id}\n"
                f"Component: {alert.component}\n"
                f"Confidence: {alert.confidence:.1%}\n"
                f"Predicted failure within: {alert.predicted_in_hours}h\n"
                f"Recommended action: {alert.recommended_action}\n"
                f"Top contributing features: {alert.top_features}"
            ),
            "urgency":  "1" if alert.severity == "CRITICAL" else "2",
            "impact":   "2",
            "category": "Hardware",
            "subcategory": "POS Terminal",
            "cmdb_ci": alert.device_id,
            "assignment_group": "Retail Tech Field Operations",
        }
        self.snow_client.create_incident(incident)

    def _get_recommendation(self, component: str, severity: str) -> str:
        recs = {
            "thermal_printer":  "Schedule roller replacement and cleaning",
            "barcode_scanner":  "Inspect glass and clean; schedule swap",
            "card_reader":      "Pre-order replacement unit; schedule swap",
            "network_adapter":  "Check cable integrity; contact ISP if needed",
            "touch_screen":     "Schedule screen replacement",
            "hardware_general": "Full hardware inspection recommended",
        }
        prefix = "URGENT: " if severity == "CRITICAL" else ""
        return prefix + recs.get(component, "Schedule inspection")
```

---

## 7. Azure Digital Twins Integration

```python
from azure.digitaltwins.core import DigitalTwinsClient

class DigitalTwinsSync:
    """
    Maintains a live digital twin for every POS device.
    Twin updated on each telemetry heartbeat.
    """
    TWIN_MODEL_ID = "dtmi:retailai:POSTerminal;1"

    def update_twin(self, device_id: str, telemetry: dict):
        patch = [
            {"op": "replace", "path": "/cpu_usage_pct",     "value": telemetry["system"]["cpu_usage_pct"]},
            {"op": "replace", "path": "/cpu_temp_celsius",  "value": telemetry["system"]["cpu_temp_celsius"]},
            {"op": "replace", "path": "/printer_status",    "value": telemetry["peripherals"]["printer"]["status"]},
            {"op": "replace", "path": "/scanner_error_rate","value": telemetry["peripherals"]["barcode_scanner"]["error_rate_pct"]},
            {"op": "replace", "path": "/last_seen",         "value": telemetry["timestamp"]},
            {"op": "replace", "path": "/transactions_1h",   "value": telemetry["application"]["transactions_1h"]},
        ]
        self.twins_client.update_digital_twin(device_id, patch)
```

---

## 8. KPIs & Monitoring

| KPI | Target | Alert Threshold |
|---|---|---|
| Failure prediction lead time | > 48 hours | < 24 hours (model degraded) |
| Failure prediction recall | > 70% of failures caught | < 60% (model retrain) |
| False positive rate | < 15% | > 25% (review thresholds) |
| Alert-to-ticket latency | < 2 minutes | > 5 minutes |
| Telemetry ingestion latency | < 60 seconds | > 120 seconds |
| Model drift PSI (features) | < 0.20 | > 0.20 (trigger retrain) |

---

## 9. Related Documents

- HLD-005: AI/ML Platform
- HLD-003: Store Edge Platform
- LLD-015: MLOps Pipeline Design
- HLD-002: POS Application (telemetry emission)
