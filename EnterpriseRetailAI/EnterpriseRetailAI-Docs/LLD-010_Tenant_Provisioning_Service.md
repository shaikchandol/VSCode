# LLD-010 — Tenant Provisioning Service
## EnterpriseRetailAI · Provisioning Pipeline, Terraform Modules, Schema Bootstrap

---

| Document ID | LLD-010 | Version | 1.0 | Status | Approved |

---

## 1. Provisioning Service Architecture

```
HQ Admin: POST /api/v1/tenants (HQ Platform API)
    │
Azure Durable Functions — TenantProvisioningOrchestrator
    │
    ├── Activity: IdentityProvisioning
    ├── Activity: KeyVaultProvisioning
    ├── Activity: DatabaseSchemaProvisioning
    ├── Activity: AKSNamespaceProvisioning
    ├── Activity: EventHubsProvisioning
    ├── Activity: APIManagementProvisioning
    ├── Activity: AIBootstrapping
    ├── Activity: EdgeDeviceProvisioning (fan-out per store)
    └── Activity: VerificationSmokeTest
            │
    Target: < 4 hours total
```

---

## 2. Terraform Module Structure

```
terraform/
├── modules/
│   ├── tenant-identity/
│   │   ├── main.tf          # AAD App Registration, Service Principal
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── tenant-keyvault/
│   │   ├── main.tf          # Key Vault + CMK + initial secrets
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── tenant-database/
│   │   ├── main.tf          # Schema creation (null_resource + psql)
│   │   ├── schema.sql       # DDL template (see LLD-013)
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── tenant-aks-namespace/
│   │   ├── main.tf          # Namespace + RBAC + NetworkPolicy
│   │   ├── rbac.tf
│   │   ├── network-policy.tf
│   │   └── resource-quota.tf
│   ├── tenant-eventhubs/
│   │   ├── main.tf          # Event Hubs namespace + topics
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── tenant-apim/
│   │   ├── main.tf          # APIM product + policy + subscription
│   │   └── policy.xml       # XML APIM policy template
│   └── tenant-ai/
│       ├── main.tf          # Azure ML workspace partition + model seeding
│       └── seed_models.py
└── environments/
    ├── prod/
    │   └── tenant_provisioning.tf
    └── staging/
        └── tenant_provisioning.tf
```

---

## 3. Terraform: Tenant Database Module

```hcl
# modules/tenant-database/main.tf

variable "tenant_id"        { type = string }
variable "franchisee_name"  { type = string }
variable "pg_server_host"   { type = string }
variable "pg_admin_user"    { type = string }
variable "pg_admin_password" { type = string sensitive = true }
variable "region"           { type = string }

locals {
  schema_name = "tenant_${replace(var.tenant_id, "-", "_")}"
  db_user     = "svc_${replace(var.tenant_id, "-", "_")}"
}

# Generate random DB password — stored in Key Vault
resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*-_=+?"
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password-${var.tenant_id}"
  value        = random_password.db_password.result
  key_vault_id = var.key_vault_id
}

# Create schema and DB user via psql provisioner
resource "null_resource" "provision_schema" {
  triggers = { tenant_id = var.tenant_id }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = {
      PGPASSWORD = var.pg_admin_password
    }
    command = <<-EOT
      psql -h ${var.pg_server_host} \
           -U ${var.pg_admin_user} \
           -d retailai \
           -v tenant_id="${var.tenant_id}" \
           -v schema_name="${local.schema_name}" \
           -v db_user="${local.db_user}" \
           -v db_password="${random_password.db_password.result}" \
           -f ${path.module}/schema.sql
    EOT
  }
}

output "schema_name"          { value = local.schema_name }
output "db_connection_string" {
  value     = "postgresql://${local.db_user}@${var.pg_server_host}/retailai"
  sensitive = true
}
```

---

## 4. Schema Bootstrap SQL Template

```sql
-- modules/tenant-database/schema.sql
-- Variables substituted by Terraform: :schema_name, :db_user, :db_password

-- Create schema
CREATE SCHEMA IF NOT EXISTS :schema_name;

-- Create application DB user
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_user') THEN
        CREATE USER :"db_user" WITH PASSWORD :'db_password';
    END IF;
END
$$;

-- Grant schema privileges
GRANT USAGE ON SCHEMA :"schema_name" TO :"db_user";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA :"schema_name" TO :"db_user";
ALTER DEFAULT PRIVILEGES IN SCHEMA :"schema_name"
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"db_user";

-- Set search path
ALTER USER :"db_user" SET search_path = :"schema_name";

-- Set tenant context enforcement
CREATE FUNCTION :"schema_name".enforce_tenant() RETURNS trigger AS $func$
BEGIN
    IF current_setting('app.tenant_id', true) != NEW.tenant_id::TEXT THEN
        RAISE EXCEPTION 'Tenant context mismatch';
    END IF;
    RETURN NEW;
END;
$func$ LANGUAGE plpgsql;

-- Run full DDL from LLD-013
\i full_schema_ddl.sql

-- Seed reference data
INSERT INTO :"schema_name".tax_rates (jurisdiction, tax_category, rate_pct, effective_from)
VALUES
    ('GBR', 'standard',  20.0, '2026-01-01'),
    ('GBR', 'reduced',    5.0, '2026-01-01'),
    ('GBR', 'zero',       0.0, '2026-01-01'),
    ('IND', 'standard',  18.0, '2026-01-01'),
    ('IND', 'reduced',    5.0, '2026-01-01'),
    ('DEU', 'standard',  19.0, '2026-01-01'),
    ('DEU', 'reduced',    7.0, '2026-01-01'),
    ('USA', 'standard',   0.0, '2026-01-01'),  -- US tax added at state level
    ('CHN', 'standard',  13.0, '2026-01-01')
ON CONFLICT (jurisdiction, tax_category) DO NOTHING;
```

---

## 5. AKS Namespace Provisioning

```python
from kubernetes import client, config

class AKSNamespaceProvisioner:
    def provision(self, tenant_id: str, tenant_name: str, region: str):
        config.load_incluster_config()
        v1  = client.CoreV1Api()
        apps = client.AppsV1Api()
        rbac = client.RbacAuthorizationV1Api()
        net  = client.NetworkingV1Api()

        ns_name = f"franchisee-{tenant_id}"

        # 1. Create namespace
        namespace = client.V1Namespace(
            metadata=client.V1ObjectMeta(
                name   = ns_name,
                labels = {
                    "tenant-id":   tenant_id,
                    "tenant-name": tenant_name,
                    "region":      region,
                    "linkerd.io/inject": "enabled",     # mTLS
                }
            )
        )
        v1.create_namespace(namespace)

        # 2. Resource Quota (prevent noisy neighbour)
        quota = client.V1ResourceQuota(
            metadata = client.V1ObjectMeta(name="tenant-quota", namespace=ns_name),
            spec = client.V1ResourceQuotaSpec(
                hard = {
                    "requests.cpu":    "4",
                    "requests.memory": "8Gi",
                    "limits.cpu":      "16",
                    "limits.memory":   "32Gi",
                    "pods":            "50",
                }
            )
        )
        v1.create_namespaced_resource_quota(ns_name, quota)

        # 3. NetworkPolicy: deny all cross-namespace traffic
        net_policy = client.V1NetworkPolicy(
            metadata = client.V1ObjectMeta(name="deny-all", namespace=ns_name),
            spec = client.V1NetworkPolicySpec(
                pod_selector = client.V1LabelSelector(),   # select all pods
                policy_types = ["Ingress", "Egress"],
                ingress = [
                    # Allow from APIM namespace only
                    client.V1NetworkPolicyIngressRule(
                        _from = [client.V1NetworkPolicyPeer(
                            namespace_selector=client.V1LabelSelector(
                                match_labels={"kubernetes.io/metadata.name": "apim"}
                            )
                        )]
                    )
                ],
                egress = [
                    # Allow to DNS
                    client.V1NetworkPolicyEgressRule(ports=[
                        client.V1NetworkPolicyPort(port=53, protocol="UDP")
                    ]),
                    # Allow to data tier (Azure SQL, Redis, Event Hubs Private Endpoints)
                    client.V1NetworkPolicyEgressRule(ports=[
                        client.V1NetworkPolicyPort(port=1433),
                        client.V1NetworkPolicyPort(port=6380),
                        client.V1NetworkPolicyPort(port=5671),
                    ])
                ]
            )
        )
        net.create_namespaced_network_policy(ns_name, net_policy)

        # 4. GitOps: Create Flux Kustomization for tenant services
        self._create_flux_kustomization(ns_name, tenant_id)
```

---

## 6. AI Bootstrapping

```python
class AIBootstrapper:
    """
    Seeds a new franchisee tenant with HQ baseline AI models.
    All 6 use cases are initialised at provisioning time.
    """
    BASELINE_MODELS = {
        "fraud-detection":    "fraud_detect_baseline_v1.0.onnx",
        "promotion-ranker":   "promo_ranker_baseline_v1.0.onnx",
        "demand-forecast":    "tft_baseline_v1.0",
        "cv-item-recognition":"cv_items_baseline_v1.0.onnx",
        "nlp-assistant":      "phi3-mini-q4.gguf",          # shared model
        "predictive-maint":   "pred_maint_baseline_v1.0.pkl",
    }

    def bootstrap(self, tenant_id: str):
        # Register tenant in Azure ML workspace partition
        self.ml_client.tenants.register(tenant_id)

        # Copy HQ baseline models to tenant model registry
        for model_name, model_file in self.BASELINE_MODELS.items():
            self.ml_client.models.register_for_tenant(
                tenant_id  = tenant_id,
                model_name = f"{model_name}-{tenant_id}",
                source     = f"hq-baseline/{model_file}",
                tags       = {"is_baseline": "true", "tenant": tenant_id},
            )

        # Seed Azure AI Search knowledge base index for NLP assistant
        self._seed_knowledge_base(tenant_id)

        # Schedule first demand forecast run (initialises feature store partition)
        self.scheduler.schedule_job(
            job_name  = f"initial-forecast-{tenant_id}",
            tenant_id = tenant_id,
            run_at    = datetime.utcnow() + timedelta(hours=2),
        )

    def _seed_knowledge_base(self, tenant_id: str):
        # Create Azure AI Search index for tenant
        index_name = f"retailai-kb-{tenant_id}"
        self.search_admin.create_index(index_name, schema=KB_INDEX_SCHEMA)

        # Import default policies and FAQs from HQ template
        documents = self.hq_template_repo.get_default_kb_documents()
        for doc in documents:
            doc["store_id"] = "global"
            doc["tenant_id"] = tenant_id
        self.search_client.upload_documents(index_name, documents)
```

---

## 7. Provisioning State Machine

```
PENDING      → IN_PROGRESS  (job started)
IN_PROGRESS  → COMPLETED    (all activities success)
IN_PROGRESS  → FAILED       (any critical activity failed)
FAILED       → RETRYING     (retry triggered by admin)
COMPLETED    → ACTIVE       (first POS enrolled)
ACTIVE       → SUSPENDED    (HQ admin action)
SUSPENDED    → ACTIVE       (HQ admin re-activation)
ACTIVE       → OFFBOARDING  (contract termination)
OFFBOARDING  → TERMINATED   (all data exported + deleted)
```

---

## 8. Idempotency & Rollback

- All Terraform resources tagged with `provisioning_job_id`
- On failure: Durable Function runs compensation activities
- Compensation: delete partially created resources in reverse order
- Re-run safety: all activities check if resource already exists (idempotent)
- Audit log: every step written to immutable provisioning_audit table

---

## 9. Related Documents

- HLD-009: Multitenancy Architecture
- LLD-013: Data Schema Design
- HLD-007: Security and Compliance

