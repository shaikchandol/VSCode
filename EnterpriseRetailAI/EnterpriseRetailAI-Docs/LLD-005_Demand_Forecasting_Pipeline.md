# LLD-005 — Demand Forecasting Pipeline
## EnterpriseRetailAI · Temporal Fusion Transformer, Azure ML Pipeline, Feature Store

---

| Document ID | LLD-005 | Type | Low-Level Design | Version | 1.0 | Status | Approved |

---

## 1. Purpose

This document defines the low-level design of the demand forecasting and replenishment pipeline, from raw sales event ingestion through the Temporal Fusion Transformer (TFT) model to actionable replenishment suggestions delivered to store managers and ERP systems.

---

## 2. End-to-End Pipeline Architecture

```
[POS Transaction Events] ──► Event Hubs ──► ADLS Gen2 (raw)
                                                    │
                                          Azure ML Pipeline Step 1:
                                          Feature Engineering (Synapse Spark)
                                                    │
                                          Azure ML Feature Store
                                          (materialised feature sets)
                                                    │
                                          Azure ML Pipeline Step 2:
                                          TFT Model Training
                                                    │
                                          Azure ML Model Registry
                                                    │
                                    ┌─────────────────────────────┐
                                    │  Inference Modes            │
                                    ├─────────────────────────────┤
                                    │ Batch (nightly):            │
                                    │  Azure ML scheduled job     │
                                    │  → SQL forecasts table      │
                                    │                             │
                                    │ On-demand API:              │
                                    │  AKS managed endpoint       │
                                    │  (per-tenant, < 5s)         │
                                    └─────────────────────────────┘
                                                    │
                                    Replenishment Service (AKS)
                                    ├ PO suggestions generated
                                    ├ Store manager notification
                                    └ SAP ERP integration
```

---

## 3. Feature Engineering Pipeline

```python
# Azure ML Pipeline Step 1 — Feature Engineering (PySpark on Synapse)
from pyspark.sql import functions as F
from pyspark.sql.window import Window

def build_forecast_features(
    transactions_df,     # raw transaction events from ADLS
    products_df,         # product catalogue
    calendar_df,         # promotional calendar + public holidays
    weather_df,          # weather forecasts per store location
    tenant_id: str,
    target_date: str,    # feature snapshot date
):
    # 1. Aggregate daily sales per SKU per store
    daily_sales = (
        transactions_df
        .filter(F.col("tenant_id") == tenant_id)
        .groupBy("store_id", "sku_id", F.to_date("completed_at").alias("sale_date"))
        .agg(
            F.sum("quantity").alias("units_sold"),
            F.sum("net_amount").alias("revenue"),
            F.countDistinct("transaction_id").alias("transaction_count"),
        )
    )

    # 2. Lag features (historical sales at different lookback windows)
    store_sku_window = Window.partitionBy("store_id", "sku_id").orderBy("sale_date")

    for lag in [1, 3, 7, 14, 21, 28]:
        daily_sales = daily_sales.withColumn(
            f"units_sold_lag_{lag}d",
            F.lag("units_sold", lag).over(store_sku_window)
        )

    # 3. Rolling aggregates
    for window_days in [7, 14, 30]:
        rolling_window = (store_sku_window
                          .rowsBetween(-window_days, -1))
        daily_sales = daily_sales.withColumn(
            f"units_sold_rolling_{window_days}d",
            F.avg("units_sold").over(rolling_window)
        )

    # 4. Seasonal decomposition signals
    daily_sales = (
        daily_sales
        .withColumn("day_of_week",  F.dayofweek("sale_date"))
        .withColumn("week_of_year", F.weekofyear("sale_date"))
        .withColumn("month",        F.month("sale_date"))
        .withColumn("is_weekend",   (F.dayofweek("sale_date") >= 6).cast("int"))
    )

    # 5. Join promotional calendar
    daily_sales = daily_sales.join(
        calendar_df.select("date", "is_holiday", "promotion_active", "event_type"),
        daily_sales["sale_date"] == calendar_df["date"],
        "left"
    )

    # 6. Join weather data
    daily_sales = daily_sales.join(
        weather_df.select("store_id", "date", "avg_temp_c", "precipitation_mm"),
        ["store_id", daily_sales["sale_date"] == weather_df["date"]],
        "left"
    )

    # 7. Join product metadata
    daily_sales = daily_sales.join(
        products_df.select("sku_id", "category", "subcategory",
                           "price_tier", "is_seasonal"),
        "sku_id",
        "left"
    )

    return daily_sales
```

---

## 4. TFT Model Architecture

```python
from pytorch_forecasting import TemporalFusionTransformer, TimeSeriesDataSet
from pytorch_forecasting.metrics import QuantileLoss
import pytorch_lightning as pl

def create_tft_model(training_data: TimeSeriesDataSet) -> TemporalFusionTransformer:
    """
    TFT configuration for retail demand forecasting.
    Outputs: P10, P50, P90 quantile forecasts (7/14/30-day horizons)
    """
    model = TemporalFusionTransformer.from_dataset(
        training_data,

        # Architecture
        hidden_size            = 64,     # embedding dimension
        lstm_layers            = 2,      # LSTM encoder/decoder depth
        attention_head_size    = 4,      # multi-head attention
        dropout                = 0.1,
        hidden_continuous_size = 32,

        # Loss: quantile regression (P10, P50, P90)
        loss = QuantileLoss(quantiles=[0.1, 0.5, 0.9]),
        output_size = 3,                 # 3 quantiles

        # Feature settings
        static_categoricals    = ["store_id", "category", "price_tier"],
        static_reals           = [],
        time_varying_known_categoricals = [
            "day_of_week", "week_of_year", "month",
            "is_holiday", "is_weekend", "promotion_active"
        ],
        time_varying_known_reals = [
            "avg_temp_c", "precipitation_mm"
        ],
        time_varying_unknown_reals = [
            "units_sold",
            "units_sold_rolling_7d",
            "units_sold_rolling_14d",
            "units_sold_rolling_30d",
        ],

        # Training
        learning_rate          = 3e-4,
        optimizer              = "adam",
        reduce_on_plateau_patience = 4,
        log_interval           = 10,
    )
    return model


def train_tft(model, train_loader, val_loader, max_epochs: int = 50):
    trainer = pl.Trainer(
        max_epochs         = max_epochs,
        accelerator        = "gpu" if torch.cuda.is_available() else "cpu",
        gradient_clip_val  = 0.1,
        callbacks          = [
            pl.callbacks.EarlyStopping("val_loss", patience=5, mode="min"),
            pl.callbacks.ModelCheckpoint(monitor="val_loss", mode="min"),
            pl.callbacks.LearningRateMonitor(),
        ],
        enable_progress_bar = True,
    )
    trainer.fit(model, train_loader, val_loader)
    return model
```

---

## 5. TimeSeriesDataSet Configuration

```python
def create_time_series_dataset(
    df,
    max_encoder_length: int = 90,   # 90 days historical context
    max_prediction_length: int = 30, # 30-day forecast horizon
) -> TimeSeriesDataSet:

    dataset = TimeSeriesDataSet(
        df,
        time_idx           = "days_from_epoch",      # integer time index
        target             = "units_sold",
        group_ids          = ["store_id", "sku_id"],
        min_encoder_length = 30,                      # need 30 days minimum history
        max_encoder_length = max_encoder_length,
        min_prediction_length = 7,
        max_prediction_length = max_prediction_length,

        static_categoricals   = ["store_id", "category", "price_tier"],
        time_varying_known_categoricals = [
            "day_of_week", "week_of_year", "month",
            "is_holiday", "is_weekend", "promotion_active"
        ],
        time_varying_known_reals = ["avg_temp_c", "precipitation_mm"],
        time_varying_unknown_reals = [
            "units_sold", "units_sold_rolling_7d",
            "units_sold_rolling_14d", "units_sold_rolling_30d"
        ],

        target_normalizer  = EncoderNormalizer(),    # per-series normalisation
        add_relative_time_idx = True,
        add_target_scales  = True,
        add_encoder_length = True,
    )
    return dataset
```

---

## 6. Evaluation Metrics

```python
def evaluate_forecast(y_true, y_pred_p50, y_pred_p10, y_pred_p90):
    """
    Primary KPI: MAPE on P50 (median) forecast < 12%
    Additional: P90 coverage (actual should be below P90 90% of time)
    """
    # MAPE — exclude zero-sales days from denominator
    mask = y_true > 0
    mape = np.mean(np.abs((y_true[mask] - y_pred_p50[mask]) / y_true[mask])) * 100

    # Bias
    bias = np.mean(y_pred_p50 - y_true)

    # P90 coverage (actual below P90)
    p90_coverage = np.mean(y_true <= y_pred_p90)

    # RMSE
    rmse = np.sqrt(np.mean((y_true - y_pred_p50) ** 2))

    metrics = {
        "mape_pct":     round(mape, 2),
        "bias":         round(bias, 3),
        "p90_coverage": round(p90_coverage, 3),
        "rmse":         round(rmse, 2),
    }

    # Gate check
    assert metrics["mape_pct"] < 12.0, \
        f"MAPE {mape:.2f}% exceeds 12% threshold"

    return metrics
```

---

## 7. Replenishment Service

```python
# AKS Service — reads forecasts from Azure SQL and generates PO suggestions

class ReplenishmentService:

    def generate_suggestions(
        self,
        tenant_id: str,
        store_id: str,
        horizon_days: int = 14,
    ) -> list[ReplenishmentSuggestion]:

        # 1. Load 14-day forecast (P50 + P90)
        forecasts = self.forecast_repo.get_forecast(
            tenant_id, store_id, days=horizon_days
        )

        # 2. Load current stock and incoming deliveries
        stock    = self.inventory_repo.get_current_stock(store_id)
        incoming = self.inventory_repo.get_incoming_deliveries(store_id)

        suggestions = []
        for sku_id, forecast in forecasts.items():
            current    = stock.get(sku_id, 0)
            on_order   = sum(d.quantity for d in incoming if d.sku_id == sku_id)
            available  = current + on_order

            # Demand over horizon (P90 for safety stock)
            expected_demand = forecast.p90_14d
            safety_stock    = int(expected_demand * 0.15)  # 15% buffer
            reorder_point   = expected_demand + safety_stock

            if available < reorder_point:
                order_qty = reorder_point - available
                priority  = "URGENT" if current < expected_demand * 0.5 else "NORMAL"

                suggestions.append(ReplenishmentSuggestion(
                    sku_id       = sku_id,
                    order_qty    = order_qty,
                    current_stock = current,
                    forecast_p50 = forecast.p50_14d,
                    forecast_p90 = forecast.p90_14d,
                    priority     = priority,
                ))

        # Sort by priority then expected days-out-of-stock
        return sorted(suggestions, key=lambda s: (s.priority, -s.current_stock))
```

---

## 8. Inference API Contract

```
POST /api/v1/ai/forecast
Headers: Authorization: Bearer {jwt}, X-Tenant-ID: {tenantId}
Request:
{
  "store_id":      "store_uuid",
  "sku_ids":       ["sku1", "sku2"],    // empty = all SKUs
  "horizon_days":  [7, 14, 30],
  "as_of_date":    "2026-06-11"
}

Response 200:
{
  "generated_at":  "2026-06-11T06:00:00Z",
  "model_version": "tft_v3.1.0",
  "forecasts": [
    {
      "sku_id": "sku1",
      "store_id": "store_uuid",
      "7d":  { "p10": 42, "p50": 61, "p90": 83 },
      "14d": { "p10": 88, "p50": 124, "p90": 167 },
      "30d": { "p10": 190, "p50": 268, "p90": 351 },
      "feature_importance": {
        "rolling_14d_avg": 0.28,
        "day_of_week":     0.19,
        "promotion_active": 0.14
      }
    }
  ]
}
```

---

## 9. Related Documents

| Document | Reference |
|---|---|
| AI/ML Platform HLD | `01_HLD/HLD-005_AI_ML_Platform.md` |
| MLOps Pipeline LLD | `02_LLD/LLD-015_MLOps_Pipeline_Design.md` |
| Data Architecture HLD | `01_HLD/HLD-006_Data_Architecture.md` |
| Data Schema LLD | `02_LLD/LLD-013_Data_Schema_Design.md` |
