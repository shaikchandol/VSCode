# Tenant Admin API Specification
## EnterpriseRetailAI · Franchisee Administration REST API Reference

---

| Document | Tenant_Admin_API_Spec | Version | v1.0 | Status | Approved |

Base URL: `https://api.retailai.com/admin/v1`
Auth: Bearer JWT (AAD OAuth2, Franchisee Admin role)
Rate Limit: 50 req/s per tenant

---

## 1. Tenant Configuration

### GET /tenants/{tenant_id}
```json
// Response 200
{
  "tenant_id": "uuid",
  "franchisee_name": "RetailCorp India Ltd.",
  "status": "ACTIVE",
  "region": "centralindia",
  "stores_count": 47,
  "pos_terminals_count": 312,
  "plan": "ENTERPRISE",
  "created_at": "ISO8601",
  "config": {
    "currency": "INR",
    "locale": "en-IN",
    "tax_jurisdiction": "IND",
    "loyalty_points_per_unit": 1,
    "offline_payment_ceiling_minor": 50000
  }
}
```

### PATCH /tenants/{tenant_id}/config
Update tenant-configurable settings (within HQ bounds).
```json
// Request
{
  "loyalty_points_per_unit": 2,
  "offline_payment_ceiling_minor": 75000,
  "receipt_header": "RetailCorp — Chennai"
}
```

---

## 2. Store Management

### GET /tenants/{tenant_id}/stores?cursor=&limit=50
### POST /tenants/{tenant_id}/stores
Create a new store within the tenant.
```json
// Request
{
  "store_name": "Chennai Central",
  "address": { "line1": "...", "city": "Chennai", "country": "IN" },
  "timezone": "Asia/Kolkata",
  "store_tier": "TIER_A",
  "expected_pos_count": 12
}
// Response 201 - includes edge device enrollment token
{ "store_id": "uuid", "enrollment_token": "eyJ...", "expires_at": "ISO8601" }
```

### DELETE /tenants/{tenant_id}/stores/{store_id}
Decommissions store: drains POS terminals, archives data, removes edge node registration.

---

## 3. Product Catalogue Overrides

### GET /tenants/{tenant_id}/products?cursor=&category=
Returns tenant-specific product overrides on top of HQ master catalogue.

### PUT /tenants/{tenant_id}/products/{sku_id}
```json
// Override HQ price or name for this franchisee's market
{ "local_name": "ऑर्गेनिक दूध 2L", "price_override_minor": 8500 }
```

---

## 4. Promotions Management

### GET /tenants/{tenant_id}/promotions?active_only=true
### POST /tenants/{tenant_id}/promotions
Create a franchisee-specific promotion.
```json
{
  "name":           "Independence Day 15% off",
  "discount_type":  "pct",
  "discount_value": 15.0,
  "conditions": { "min_basket_minor": 20000 },
  "valid_from":     "2026-08-15T00:00:00Z",
  "valid_until":    "2026-08-15T23:59:59Z",
  "budget_minor":   500000
}
```

---

## 5. Staff & Access Management

### GET /tenants/{tenant_id}/staff
### POST /tenants/{tenant_id}/staff
Creates staff account, sends AAD invite email.
```json
{ "email": "john@store.com", "role": "STORE_MANAGER", "store_id": "uuid" }
```

### DELETE /tenants/{tenant_id}/staff/{staff_id}
Revokes AAD access immediately; deactivates all POS sessions.

---

## 6. Reports & Analytics

### GET /tenants/{tenant_id}/reports/revenue?from=&to=&group_by=store|day
### GET /tenants/{tenant_id}/reports/ai-performance
Returns per-AI-use-case KPIs for the tenant.
```json
{
  "fraud_detection": { "tpr": 0.961, "fpr": 0.018, "alerts_last_30d": 23 },
  "demand_forecast": { "mape_pct": 9.4, "stockouts_prevented": 18 },
  "personalisation": { "basket_lift_pct": 11.2, "promo_redemption_rate": 0.34 }
}
```

---

## 7. Data Subject Rights (GDPR/DPDP)

### POST /tenants/{tenant_id}/dsar/access
Submit a data subject access request.

### POST /tenants/{tenant_id}/dsar/erasure
Submit a right-to-erasure request (24h SLA).

### GET /tenants/{tenant_id}/dsar/{request_id}/status
Check DSAR processing status.
