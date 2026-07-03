# ADR-004 — K3s for Store Edge Orchestration
## EnterpriseRetailAI · Architecture Decision Record

| ID | ADR-004 | Status | Approved | Date | 2026-02 | Decider | CTO + Head of Retail Tech |

---

## Context

Each store edge server must run 8+ containerised services (store API, inventory, loyalty, sync manager, NLP SLM, Kafka, PostgreSQL, monitoring) alongside Azure IoT Edge AI modules. Three deployment models were evaluated.

---

## Options Considered

### Option A: Docker Compose
- Simple, well-understood
- No automatic service restart / health management beyond basic
- No resource quotas between services — noisy neighbour risk
- No rolling deployment — update = downtime

### Option B: K3s (Lightweight Kubernetes) ✅ (Selected)
- Full Kubernetes API on ~512MB RAM (vs. 2GB+ for full K8s)
- HPA, resource quotas, rolling deployments, liveness/readiness probes
- GitOps via Flux v2 (same toolchain as cloud AKS — operational consistency)
- Linkerd service mesh: mTLS between store services with zero code change

### Option C: Bare Metal (systemd services)
- Minimum overhead
- No container isolation — services share filesystem and process namespace
- No rolling updates, no health management, no resource limits
- Unacceptable for AI module isolation

---

## Decision

**K3s** is adopted for all Tier A and Tier B store edge nodes.
Tier C (single-POS kiosks) use Docker Compose (reduced complexity justified).

---

## Consequences

**Positive:**
- Same GitOps pipeline (Flux v2) for cloud AKS and store K3s — one workflow
- K3s auto-restarts failed pods — store services self-heal without IT intervention
- Resource quotas prevent a runaway AI module from starving the sync manager

**Negative:**
- K3s adds ~300MB RAM overhead vs. Docker Compose
- Store technicians need basic kubectl training
- Certificate management for K3s API requires secure initial provisioning

**Hardware Baseline:** Intel NUC 12 Pro (4-core, 16GB RAM) — confirmed compatible.
