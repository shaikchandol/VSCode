# Store Management API Specification
## EnterpriseRetailAI · Store Admin REST API Reference

---

| Document | Store_Management_API_Spec | Version | v1.0 | Status | Approved |

Base URL: `https://api.retailai.com/store/v1`
Auth: Bearer JWT (AAD OAuth2, Store Manager role)
Rate Limit: 100 req/s per store

---

## 1. Store Status & Health

### GET /stores/{store_id}/status
```json
// Response 200
{
  "store_id": "uuid",
  "store_name": "Chennai Central",
  "connectivity": "ONLINE",         // ONLINE | OFFLINE | SYNC_RECOVERY | DEGRADED
  "last_cloud_sync": "2026-06-11T10:05:00Z",
  "pos_terminals": [
    { "pos_id": "uuid", "name": "POS-01", "status": "ACTIVE", "sync_depth": 0 }
  ],
  "inventory_synced": true,
  "open_shifts": 3,
  "active_promotions": 5
}
```

### GET /stores/{store_id}/alerts
Returns active operational alerts (low stock, maintenance, fraud).
```json
// Response 200
{
  "alerts": [
    {
      "alert_id": "uuid",
      "type": "LOW_STOCK",
      "severity": "WARNING",
      "sku_id": "sku_042",
      "sku_name": "Organic Milk 2L",
      "current_qty": 3,
      "reorder_point": 10,
      "created_at": "ISO8601"
    }
  ]
}
```

---

## 2. Inventory

### GET /stores/{store_id}/inventory
Query params: `sku_ids` (comma-separated), `low_stock_only` (bool), `category`, `cursor`, `limit`

```json
// Response 200
{
  "inventory": [
    {
      "sku_id": "uuid",
      "sku_name": "Organic Whole Milk 2L",
      "barcode": "5012345678900",
      "quantity_on_hand": 42,
      "quantity_reserved": 2,
      "reorder_point": 10,
      "reorder_qty": 50,
      "last_count_at": "ISO8601"
    }
  ],
  "cursor_next": null,
  "total_count": 1842
}
```

### POST /stores/{store_id}/inventory/adjust
Manual stock adjustment (manager PIN required).
```json
// Request
{
  "sku_id": "uuid",
  "quantity_delta": -5,
  "reason": "SHRINKAGE",           // SALE | RETURN | RECEIPT | ADJUSTMENT | SHRINKAGE
  "notes": "Damaged on shelf",
  "adjusted_by": "manager_uuid"
}
// Response 201
{ "new_quantity_on_hand": 37, "movement_id": "uuid" }
```

---

## 3. Shifts

### GET /stores/{store_id}/shifts?date=2026-06-11
```json
// Response 200
{
  "shifts": [
    {
      "shift_id": "uuid",
      "cashier_name": "John Smith",
      "pos_id": "uuid",
      "opened_at": "ISO8601",
      "closed_at": "ISO8601",
      "status": "CLOSED",
      "tx_count": 87,
      "gross_sales_minor": 245000,
      "cash_variance_minor": 50
    }
  ]
}
```

### POST /stores/{store_id}/shifts/{shift_id}/close
Triggers EOD reconciliation.
```json
// Request
{ "closing_float_minor": 50000, "closed_by": "manager_uuid" }
// Response 200
{ "shift_id": "uuid", "status": "RECONCILED", "variance_minor": 50, "report_url": "https://..." }
```

---

## 4. Reports

### GET /stores/{store_id}/reports/sales
Query params: `from`, `to`, `group_by` (hour | day | week)

```json
// Response 200
{
  "period": { "from": "ISO8601", "to": "ISO8601" },
  "summary": {
    "gross_sales_minor": 1245000,
    "transactions_count": 847,
    "avg_basket_minor": 1471,
    "discount_total_minor": 87000
  },
  "time_series": [
    { "period_start": "ISO8601", "sales_minor": 85000, "tx_count": 47 }
  ]
}
```

### GET /stores/{store_id}/reports/end-of-day?date=2026-06-11
Returns PDF URL + JSON reconciliation summary.
```json
// Response 200
{
  "date": "2026-06-11",
  "pdf_url": "https://reports.retailai.com/store_001/eod_20260611.pdf",
  "summary": {
    "gross_sales_minor": 1245000,
    "voids_count": 3,
    "returns_count": 7,
    "offline_period_minutes": 0,
    "offline_transactions": 0,
    "payment_tokens_settled": 0
  }
}
```

---

## 5. Device Management

### GET /stores/{store_id}/devices
Lists all POS terminals and store edge nodes.

### POST /stores/{store_id}/devices/{device_id}/restart
Triggers graceful restart of a POS terminal via IoT Hub.

### GET /stores/{store_id}/devices/{device_id}/telemetry
Returns last 24h telemetry for a device.

---

## 6. Related Documents
- LLD-014: API Design
- HLD-003: Store Edge Platform
