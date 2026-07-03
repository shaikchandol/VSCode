# Cloud-Agnostic Deployment Guide

## Overview

Deploy BookRatings microservices to any cloud provider (Azure, AWS, GCP) using cloud-agnostic infrastructure-as-code with Terraform and Kubernetes.

## Project Structure

```
Deployment/
├── kubernetes/                          # Cloud-agnostic K8s manifests
│   ├── namespace.yaml
│   ├── configmap.yaml                   # Environment configuration
│   ├── secrets.yaml                     # Secrets (encrypted in vault)
│   ├── services/
│   │   ├── books-deployment.yaml
│   │   ├── ratings-deployment.yaml
│   │   ├── users-deployment.yaml
│   │   ├── admin-deployment.yaml
│   │   ├── reporting-deployment.yaml
│   │   └── gateway-deployment.yaml
│   ├── databases/
│   │   ├── sqlserver-statefulset.yaml
│   │   ├── postgres-statefulset.yaml
│   │   ├── redis-deployment.yaml
│   │   └── rabbitmq-deployment.yaml
│   ├── ingress/
│   │   ├── ingress-nginx.yaml
│   │   └── api-gateway-ingress.yaml
│   ├── monitoring/
│   │   ├── prometheus-deployment.yaml
│   │   └── grafana-deployment.yaml
│   └── kustomization.yaml               # Multi-environment support
│
├── terraform/
│   ├── main.tf                          # Main configuration
│   ├── variables.tf                     # Input variables
│   ├── outputs.tf                       # Output values
│   ├── providers.tf                     # Cloud provider configuration
│   │
│   ├── modules/
│   │   ├── kubernetes/                  # Kubernetes cluster
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── database/                    # Database provisioning
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   │
│   │   ├── cache/                       # Redis cache
│   │   │   ├── main.tf
│   │   │   └── variables.tf
│   │   │
│   │   ├── messaging/                   # Message broker
│   │   │   ├── main.tf
│   │   │   └── variables.tf
│   │   │
│   │   ├── monitoring/                  # Observability stack
│   │   │   ├── main.tf
│   │   │   └── variables.tf
│   │   │
│   │   ├── secrets/                     # Secrets vault
│   │   │   ├── main.tf
│   │   │   └── variables.tf
│   │   │
│   │   └── networking/                  # VPC, load balancer
│   │       ├── main.tf
│   │       └── variables.tf
│   │
│   ├── environments/
│   │   ├── dev.tfvars                   # Development variables
│   │   ├── staging.tfvars               # Staging variables
│   │   └── production.tfvars            # Production variables
│   │
│   └── cloud-providers/
│       ├── azure.tf                     # Azure-specific config
│       ├── aws.tf                       # AWS-specific config
│       └── gcp.tf                       # GCP-specific config
│
├── helm/
│   └── bookratings/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-staging.yaml
│       ├── values-production.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           └── configmap.yaml
│
└── scripts/
    ├── deploy.sh                        # Deploy to cloud
    ├── rollback.sh                      # Rollback deployment
    ├── scale.sh                         # Scale services
    └── health-check.sh                  # Verify health
```

## Kubernetes Manifests (Cloud-Agnostic)

### namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bookratings
  labels:
    name: bookratings
---
apiVersion: v1
kind: Namespace
metadata:
  name: bookratings-monitoring
  labels:
    name: bookratings-monitoring
```

### configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bookratings-config
  namespace: bookratings
data:
  ASPNETCORE_ENVIRONMENT: "Production"
  LOG_LEVEL: "Information"
  KEYCLOAK_AUTHORITY: "https://keycloak.bookratings.com"
  OTEL_EXPORTER_OTLP_ENDPOINT: "http://jaeger-collector:4317"
  DAPR_HTTP_PORT: "3500"
  DAPR_GRPC_PORT: "50001"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: bookratings-services
  namespace: bookratings
data:
  BOOKS_SERVICE_URL: "http://books-service:5001"
  RATINGS_SERVICE_URL: "http://ratings-service:5002"
  USERS_SERVICE_URL: "http://users-service:5003"
  ADMIN_SERVICE_URL: "http://admin-service:5004"
  REPORTING_SERVICE_URL: "http://reporting-service:5005"
```

### books-deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: books-service
  namespace: bookratings
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: books-service
  template:
    metadata:
      labels:
        app: books-service
        version: v1
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "books-service"
        dapr.io/app-port: "5001"
        dapr.io/app-protocol: "http"
    spec:
      serviceAccountName: books-service
      containers:
      - name: books-service
        image: bookratings/books-service:latest
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 5001
          protocol: TCP
        - name: metrics
          containerPort: 9090
          protocol: TCP
        
        envFrom:
        - configMapRef:
            name: bookratings-config
        - configMapRef:
            name: bookratings-services
        - secretRef:
            name: bookratings-secrets
        
        env:
        - name: ConnectionStrings__DefaultConnection
          valueFrom:
            secretKeyRef:
              name: bookratings-secrets
              key: database-connection-string
        - name: Keycloak__ClientSecret
          valueFrom:
            secretKeyRef:
              name: bookratings-secrets
              key: keycloak-secret
        
        resources:
          requests:
            cpu: "250m"
            memory: "512Mi"
          limits:
            cpu: "500m"
            memory: "1Gi"
        
        livenessProbe:
          httpGet:
            path: /health/live
            port: http
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        readinessProbe:
          httpGet:
            path: /health/ready
            port: http
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        volumeMounts:
        - name: logs
          mountPath: /var/log/bookratings
      
      volumes:
      - name: logs
        emptyDir: {}
      
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - books-service
              topologyKey: kubernetes.io/hostname
---
apiVersion: v1
kind: Service
metadata:
  name: books-service
  namespace: bookratings
spec:
  selector:
    app: books-service
  type: ClusterIP
  ports:
  - name: http
    port: 5001
    targetPort: 5001
    protocol: TCP
  - name: metrics
    port: 9090
    targetPort: 9090
    protocol: TCP
```

### sqlserver-statefulset.yaml

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sqlserver-pvc
  namespace: bookratings
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: sqlserver
  namespace: bookratings
spec:
  serviceName: sqlserver
  replicas: 1
  selector:
    matchLabels:
      app: sqlserver
  template:
    metadata:
      labels:
        app: sqlserver
    spec:
      containers:
      - name: sqlserver
        image: mcr.microsoft.com/mssql/server:2022-latest
        ports:
        - containerPort: 1433
          name: sqlserver
        
        env:
        - name: MSSQL_SA_PASSWORD
          valueFrom:
            secretKeyRef:
              name: bookratings-secrets
              key: sqlserver-password
        - name: ACCEPT_EULA
          value: "Y"
        - name: MSSQL_PID
          value: "Standard"
        - name: MSSQL_MEMORY_LIMIT_MB
          value: "2048"
        
        resources:
          requests:
            memory: "2Gi"
            cpu: "1"
          limits:
            memory: "4Gi"
            cpu: "2"
        
        volumeMounts:
        - name: sqlserver-data
          mountPath: /var/opt/mssql
      
      volumes:
      - name: sqlserver-data
        persistentVolumeClaim:
          claimName: sqlserver-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: sqlserver
  namespace: bookratings
spec:
  selector:
    app: sqlserver
  type: ClusterIP
  ports:
  - port: 1433
    targetPort: 1433
```

### ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bookratings-ingress
  namespace: bookratings
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - api.bookratings.com
    secretName: bookratings-tls
  rules:
  - host: api.bookratings.com
    http:
      paths:
      - path: /api/books
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 5000
      - path: /api/ratings
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 5000
      - path: /api/users
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 5000
```

## Terraform Configuration (Cloud-Agnostic)

### main.tf

```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "terraform-state"
    storage_account_name = "bookratingstate"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
  }
}

locals {
  environment = var.environment
  region      = var.region
  app_name    = "bookratings"
  tags = {
    Environment = local.environment
    Project     = local.app_name
    ManagedBy   = "Terraform"
  }
}

# Kubernetes Cluster
module "kubernetes" {
  source = "./modules/kubernetes"

  cluster_name    = "${local.app_name}-${local.environment}"
  environment     = local.environment
  region          = local.region
  cloud_provider  = var.cloud_provider
  node_count      = var.node_count
  node_vm_size    = var.node_vm_size
  tags            = local.tags
}

# Database
module "database" {
  source = "./modules/database"

  database_name   = "${local.app_name}-db"
  environment     = local.environment
  region          = local.region
  cloud_provider  = var.cloud_provider
  storage_size_gb = var.database_storage_gb
  tags            = local.tags
}

# Cache (Redis)
module "cache" {
  source = "./modules/cache"

  cache_name     = "${local.app_name}-redis"
  environment    = local.environment
  region         = local.region
  cloud_provider = var.cloud_provider
  tags           = local.tags
}

# Message Queue (RabbitMQ)
module "messaging" {
  source = "./modules/messaging"

  broker_name    = "${local.app_name}-rabbitmq"
  environment    = local.environment
  region         = local.region
  cloud_provider = var.cloud_provider
  tags           = local.tags
}

# Secrets Vault
module "secrets" {
  source = "./modules/secrets"

  vault_name     = "${local.app_name}-vault"
  environment    = local.environment
  region         = local.region
  cloud_provider = var.cloud_provider
  tags           = local.tags
}

# Monitoring
module "monitoring" {
  source = "./modules/monitoring"

  environment     = local.environment
  region          = local.region
  cloud_provider  = var.cloud_provider
  tags            = local.tags
}

# Networking
module "networking" {
  source = "./modules/networking"

  network_name   = "${local.app_name}-network"
  environment    = local.environment
  region         = local.region
  cloud_provider = var.cloud_provider
  tags           = local.tags
}
```

### variables.tf

```hcl
variable "cloud_provider" {
  description = "Cloud provider (azure, aws, gcp)"
  type        = string
  validation {
    condition     = contains(["azure", "aws", "gcp"], var.cloud_provider)
    error_message = "Cloud provider must be azure, aws, or gcp."
  }
}

variable "environment" {
  description = "Environment (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "region" {
  description = "Cloud region"
  type        = string
  default     = "us-east-1"
}

variable "node_count" {
  description = "Number of Kubernetes nodes"
  type        = number
  default     = 3
}

variable "node_vm_size" {
  description = "VM size for nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "database_storage_gb" {
  description = "Database storage size in GB"
  type        = number
  default     = 50
}

variable "enable_monitoring" {
  description = "Enable monitoring stack"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

### environments/production.tfvars

```hcl
cloud_provider        = "azure"
environment          = "production"
region               = "eastus"
node_count           = 5
node_vm_size         = "Standard_D4s_v3"
database_storage_gb  = 200
enable_monitoring    = true
```

### environments/aws.tfvars

```hcl
cloud_provider        = "aws"
environment          = "production"
region               = "us-east-1"
node_count           = 5
node_vm_size         = "t3.xlarge"
database_storage_gb  = 200
enable_monitoring    = true
```

### environments/gcp.tfvars

```hcl
cloud_provider        = "gcp"
environment          = "production"
region               = "us-central1"
node_count           = 5
node_vm_size         = "n1-standard-2"
database_storage_gb  = 200
enable_monitoring    = true
```

## Deployment Script

### deploy.sh

```bash
#!/bin/bash

set -e

CLOUD_PROVIDER=${1:-azure}
ENVIRONMENT=${2:-production}
REGION=${3:-us-east-1}

echo "🚀 Deploying BookRatings to $CLOUD_PROVIDER ($ENVIRONMENT)"

# Validate inputs
if [[ ! " azure aws gcp " =~ " $CLOUD_PROVIDER " ]]; then
    echo "❌ Invalid cloud provider: $CLOUD_PROVIDER"
    exit 1
fi

# Initialize Terraform
cd Deployment/terraform
terraform init

# Plan deployment
echo "📋 Planning deployment..."
terraform plan -var-file="environments/$ENVIRONMENT.tfvars" -out=tfplan

# Ask for confirmation
read -p "Do you want to proceed with deployment? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Apply Terraform
echo "🔨 Applying Terraform..."
terraform apply tfplan

# Get outputs
KUBECONFIG=$(terraform output -raw kubeconfig_path)
export KUBECONFIG

# Deploy Kubernetes manifests
echo "🐳 Deploying Kubernetes manifests..."
kubectl apply -f ../kubernetes/namespace.yaml
kubectl apply -f ../kubernetes/configmap.yaml
kubectl apply -f ../kubernetes/services/

# Deploy Helm charts
echo "📦 Deploying Helm charts..."
helm repo add bookratings https://charts.bookratings.com
helm repo update
helm upgrade --install bookratings bookratings/bookratings \
  -f ../helm/values-$ENVIRONMENT.yaml \
  -n bookratings

# Wait for rollout
echo "⏳ Waiting for deployments to be ready..."
kubectl rollout status deployment/api-gateway -n bookratings --timeout=10m

# Run health checks
echo "✅ Running health checks..."
./../../scripts/health-check.sh

echo "✨ Deployment complete!"
```

### rollback.sh

```bash
#!/bin/bash

DEPLOYMENT=${1:-api-gateway}
NAMESPACE=${2:-bookratings}
REVISION=${3:-0}

echo "🔄 Rolling back $DEPLOYMENT in $NAMESPACE..."

kubectl rollout undo deployment/$DEPLOYMENT \
  -n $NAMESPACE \
  --to-revision=$REVISION

kubectl rollout status deployment/$DEPLOYMENT \
  -n $NAMESPACE \
  --timeout=5m

echo "✅ Rollback complete!"
```

## Deployment by Cloud Provider

### Azure Deployment

```bash
./deploy.sh azure production eastus
```

### AWS Deployment

```bash
./deploy.sh aws production us-east-1
```

### GCP Deployment

```bash
./deploy.sh gcp production us-central1
```

## Benefits

✅ **Cloud-Agnostic**: Same Terraform/Kubernetes configs work on any cloud
✅ **Infrastructure as Code**: Version-controlled, reproducible deployments
✅ **Multi-Environment**: Easy promotion from dev → staging → production
✅ **Auto-Scaling**: Kubernetes handles scaling based on metrics
✅ **Self-Healing**: Automatic container restart on failure
✅ **Rollback**: Easy rollback to previous versions
✅ **Secrets Management**: Integration with cloud vaults (Key Vault, Secrets Manager, Secret Manager)
✅ **Monitoring**: Built-in health checks, metrics, logs
✅ **Cost Optimization**: Right-sized resources per environment
