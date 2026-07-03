# LLD-003 — Store Edge Orchestration
## EnterpriseRetailAI · K3s Configuration, Service Mesh, Pod Specs, Health Checks

| Document ID | LLD-003 | Version | 1.0 | Status | Approved |

---

## 1. K3s Cluster Configuration

```yaml
# /etc/rancher/k3s/config.yaml
cluster-init: true
disable:
  - traefik           # replaced by NGINX Ingress
  - servicelb         # replaced by MetalLB
tls-san:
  - store-edge.local
  - 192.168.1.1       # store LAN IP
data-dir: /var/lib/rancher/k3s
kubelet-arg:
  - "max-pods=110"
  - "eviction-hard=memory.available<200Mi"
  - "system-reserved=cpu=200m,memory=512Mi"
kube-apiserver-arg:
  - "audit-log-path=/var/log/k3s-audit.log"
  - "audit-log-maxage=7"
  - "audit-policy-file=/etc/k3s/audit-policy.yaml"
```

---

## 2. Namespace Layout

```
k3s namespaces:
├── kube-system      (K3s system pods)
├── metallb-system   (LoadBalancer)
├── ingress-nginx    (Ingress controller)
├── monitoring       (Prometheus + Grafana)
├── iot-edge         (Azure IoT Edge modules)
└── store-services   (all store application pods)
```

---

## 3. Store Orchestration API Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: store-orch-api
  namespace: store-services
spec:
  replicas: 2
  selector:
    matchLabels:
      app: store-orch-api
  template:
    metadata:
      labels:
        app: store-orch-api
    spec:
      containers:
      - name: store-orch-api
        image: retailai.azurecr.io/store-orch-api:2.4.1
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 8443
          name: grpc
        resources:
          requests:
            cpu: "200m"
            memory: "256Mi"
          limits:
            cpu: "1000m"
            memory: "512Mi"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
        env:
        - name: TENANT_ID
          valueFrom:
            secretKeyRef:
              name: store-config
              key: tenant_id
        - name: STORE_ID
          valueFrom:
            configMapKeyRef:
              name: store-config
              key: store_id
        - name: PG_CONNECTION
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: connection_string
        volumeMounts:
        - name: models
          mountPath: /models
          readOnly: true
      volumes:
      - name: models
        hostPath:
          path: /var/retailai/models
          type: DirectoryOrCreate
```

---

## 4. NetworkPolicy (store-services namespace)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: store-services-policy
  namespace: store-services
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow POS terminals from LAN
  - from:
    - ipBlock:
        cidr: 192.168.1.0/24
    ports:
    - port: 8080
    - port: 8443
  # Allow inter-namespace iot-edge
  - from:
    - namespaceSelector:
        matchLabels:
          name: iot-edge
  egress:
  # Allow to PostgreSQL
  - to:
    - ipBlock:
        cidr: 127.0.0.1/32
    ports:
    - port: 5432
  # Allow to Kafka
  - ports:
    - port: 9092
  # Allow to Azure IoT Hub (AMQP/MQTT)
  - ports:
    - port: 443
    - port: 8883
    - port: 5671
```

---

## 5. Service Mesh (Linkerd)

```bash
# Install Linkerd on K3s
linkerd install --set proxyInit.runAsRoot=true | kubectl apply -f -

# Annotate store-services namespace for mTLS injection
kubectl annotate namespace store-services \
  linkerd.io/inject=enabled

# Verify mTLS between store-orch-api and inventory-svc
linkerd viz edges pod -n store-services
# Expected: all edges show ✓ mTLS
```

---

## 6. PostgreSQL Deployment (K3s)

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: store-services
spec:
  serviceName: postgresql
  replicas: 1      # Tier B stores; Tier A uses Patroni HA
  template:
    spec:
      containers:
      - name: postgresql
        image: postgres:16-alpine
        env:
        - name: POSTGRES_DB
          value: "retailai_store"
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: pg-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: pg-credentials
              key: password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "2000m"
            memory: "4Gi"
        volumeMounts:
        - name: pg-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: pg-data
    spec:
      storageClassName: local-path
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 100Gi
```

---

## 7. IoT Edge Module Manifest

```json
{
  "modulesContent": {
    "$edgeAgent": {
      "properties.desired": {
        "schemaVersion": "1.1",
        "runtime": {
          "type": "docker",
          "settings": {
            "minDockerVersion": "v1.25"
          }
        },
        "systemModules": {
          "edgeAgent": { "type": "docker", "settings": {
            "image": "mcr.microsoft.com/azureiotedge-agent:1.4"
          }},
          "edgeHub": { "type": "docker", "settings": {
            "image": "mcr.microsoft.com/azureiotedge-hub:1.4",
            "createOptions": "{\"HostConfig\":{\"PortBindings\":{\"5671/tcp\":[{\"HostPort\":\"5671\"}],\"8883/tcp\":[{\"HostPort\":\"8883\"}],\"443/tcp\":[{\"HostPort\":\"443\"}]}}}"
          }}
        },
        "modules": {
          "fraud-detect-edge": {
            "type": "docker",
            "settings": {
              "image": "retailai.azurecr.io/fraud-detect-edge:2.4.1",
              "createOptions": "{\"HostConfig\":{\"Memory\":268435456}}"
            },
            "env": {
              "MODEL_VERSION": {"value": "2.4.1"},
              "INFERENCE_PORT": {"value": "8090"}
            }
          },
          "cv-item-recognition": {
            "type": "docker",
            "settings": {
              "image": "retailai.azurecr.io/cv-item-recognition:1.8.0",
              "createOptions": "{\"HostConfig\":{\"Memory\":1073741824,\"Devices\":[{\"PathOnHost\":\"/dev/video0\",\"PathInContainer\":\"/dev/video0\",\"CgroupPermissions\":\"mrw\"}]}}"
            }
          },
          "nlp-phi3-assistant": {
            "type": "docker",
            "settings": {
              "image": "retailai.azurecr.io/nlp-phi3-assistant:1.2.0",
              "createOptions": "{\"HostConfig\":{\"Memory\":3221225472}}"
            }
          }
        }
      }
    }
  }
}
```

---

## 8. Health Check Endpoints (all store services)

| Endpoint | Response | Checked By | Condition |
|---|---|---|---|
| `GET /health/live` | 200 OK | K3s liveness probe | Process running |
| `GET /health/ready` | 200 OK | K3s readiness probe | DB connected + models loaded |
| `GET /health/startup` | 200 OK | K3s startup probe | Initialisation complete |
| `GET /metrics` | Prometheus text | Prometheus scraper | Always |
| `GET /health/deep` | JSON detail | Manual / monitoring | Full dependency check |

---

## 9. Related Documents

- HLD-003: Store Edge Platform
- LLD-011: Event Sync CRDT Engine
- LLD-002: Offline Sync Agent
