# HLD-007 — Security & Compliance Architecture
## EnterpriseRetailAI · Zero Trust, PCI-DSS, GDPR, CCPA, DPDP, PIPL

---

| Document ID | HLD-007 | Version | 1.0 | Status | Approved |

---

## 1. Security Architecture Principles

1. **Zero Trust** — No implicit trust at any boundary; verify every identity, every time.
2. **Least Privilege** — Every identity (human, service, device) receives minimum permissions.
3. **Encryption Everywhere** — All data encrypted at rest (AES-256) and in transit (TLS 1.3).
4. **Defence in Depth** — Multiple layers of control; no single point of failure.
5. **Immutable Audit** — All security events written to tamper-proof, immutable log store.

---

## 2. Zero Trust Architecture

```
Identity → Device → Network → Application → Data
   │          │         │          │           │
   AAD/B2C    X.509     NSG+Fw     APIM+RBAC   Encrypt
   MFA        TPM       Zero-trust  mTLS/JWT    CMK+TDE
   PIM        MDM       Private EP  OPA policy  Column enc
```

### Identity Tiers

| Identity Type | Provider | Auth Method | MFA | Privilege |
|---|---|---|---|---|
| HQ Platform Admin | Azure AD + PIM | Certificate + FIDO2 | ✅ Mandatory | Just-In-Time |
| Franchisee Admin | Azure AD B2B | Username + Authenticator | ✅ Mandatory | Tenant-scoped |
| Store Manager | Azure AD | Username + Authenticator | ✅ Mandatory | Store-scoped |
| Cashier / POS Staff | Azure AD + local PIN | Badge + PIN | PIN (2nd factor) | POS-scoped |
| Customer | Azure AD B2C | Email/Social/OTP | OTP for DSAR | Profile-only |
| AKS Workloads | Workload Identity (OIDC) | MSI token | N/A (service) | Namespace-scoped |
| Store Edge Nodes | IoT Hub + X.509 | Device cert (TPM) | N/A (device) | Store-scoped |
| POS Terminals | IoT Hub + X.509 | Device cert (TPM) | N/A (device) | Terminal-scoped |

---

## 3. PCI-DSS v4.0 Controls

### Cardholder Data Environment (CDE) Scope

```
IN SCOPE (CDE):
  ├ POS terminal hardware (P2PE listed device — reduces scope)
  ├ Payment Service (AKS namespace: franchisee-{id}/payment-svc)
  ├ Azure SQL payment tables (column-level encrypted)
  ├ Azure Key Vault payment tokenisation keys
  └ Azure Event Hubs payment-events topic

OUT OF SCOPE (P2PE reduces):
  ├ All other POS application code
  ├ Store edge services (never see plaintext card data)
  └ All other cloud services
```

### PCI Controls Matrix

| Req | Control | Technology |
|---|---|---|
| 1 — Network | Microsegmentation | Cilium NetworkPolicy; payment-svc isolated namespace |
| 2 — Config | Hardened images | CIS Benchmark; Trivy image scan; no default passwords |
| 3 — Stored data | No PAN storage | P2PE; tokenisation only; card data never in app layer |
| 4 — Transit | TLS 1.3 enforced | min TLS 1.2 config (Azure Policy); TLS 1.3 preferred |
| 5 — Malware | EDR | Defender for Endpoint on all devices; Defender for Containers |
| 6 — Secure dev | SAST + DAST | Checkmarx (SAST), OWASP ZAP (DAST), Dependabot (SCA) |
| 7 — Access | RBAC + PIM | Azure PIM for admin roles; K8s RBAC per namespace |
| 8 — Identity | MFA + device auth | AAD Conditional Access; device certificate on POS |
| 9 — Physical | Site security | Tamper-evident POS cases; back-office server room access control |
| 10 — Audit | Immutable logs | Azure Immutable Blob; PgAudit; Sentinel SIEM |
| 11 — Testing | ASV + pentest | Quarterly Qualys ASV scan; annual penetration test (CREST) |
| 12 — Policy | ISMS | ISO 27001-aligned ISMS; ARB-enforced architecture standards |

---

## 4. GDPR / CCPA / DPDP / PIPL Controls

### Privacy-by-Design Controls

| Control | Implementation |
|---|---|
| Data minimisation | Only collect PII fields required for stated purpose |
| Purpose limitation | Azure Purview purpose tagging; query audit |
| Storage limitation | Lifecycle policies (data deleted per retention schedule) |
| Consent management | Explicit opt-in per purpose; stored with timestamp + channel |
| Data subject rights | Automated erasure, portability, access (24h SLA for erasure) |
| Cross-border transfers | SCCs for EU→non-EU; PIPL assessment for China |
| Data residency | Azure Policy: deny storage creation outside approved regions |
| Privacy impact | DPIA completed for AI profiling (personalisation, fraud scoring) |
| DPO / CPO | Appointed per regulation; contact details in privacy notice |

### Regulation Coverage

| Obligation | GDPR | CCPA | India DPDP | China PIPL |
|---|---|---|---|---|
| Lawful basis | Art 6 documented | ✅ | ✅ | ✅ |
| Consent | Explicit, purpose-specific | Opt-out right | Explicit | Explicit |
| Erasure | 24h SLA | 45 days | 15 days | Promptly |
| Portability | Machine-readable export | ✅ | ✅ | ✅ |
| Breach notification | 72h to DPA | 72h to AG | 72h to DPBI | 24h to CAC |
| Cross-border | SCCs + IDTA | — | DPA required | PIPL assessment |
| AI profiling | Art 22 human override | ✅ | ✅ | ✅ |
| Data localisation | — | — | Significant data in India | All personal data in China |

---

## 5. Network Security Controls

```
Perimeter:
  Azure DDoS Protection Standard (all public IPs)
  Azure Front Door WAF (OWASP 3.2 + custom rules for POS patterns)
  
Zone segmentation:
  Public Zone:  Front Door → APIM only (no direct AKS access)
  App Zone:     AKS cluster (private endpoint, no internet ingress)
  Data Zone:    SQL/Cosmos/Event Hubs (private endpoints only)
  Mgmt Zone:    Bastion + DevOps agents (jump host pattern)
  
Intra-cluster:
  Cilium eBPF NetworkPolicy: deny-all default; allow-list per service
  Istio service mesh: mTLS between all pods (certificate rotation: 24h)
  OPA/Gatekeeper: policy enforcement (no privileged containers, etc.)

Store → Cloud:
  IPSEC VPN (IKEv2) via Azure VPN Gateway per store
  Alternative: Azure Private Link over ExpressRoute for large stores
```

---

## 6. Security Monitoring (SOC)

```
Signals → Microsoft Sentinel (SIEM/SOAR)

Detection rules:
  ├ Cross-tenant SQL query attempt (PgAudit → Sentinel)
  ├ Fraud score surge >3σ in store (Event Hubs → Stream Analytics → Sentinel)
  ├ Offline payment ceiling breach attempt (App Insights → Sentinel)
  ├ POS device cert mismatch on IoT Hub connection
  ├ AI model hash mismatch at startup (IoT Edge telemetry → Sentinel)
  ├ Privileged identity elevation outside business hours (PIM → Sentinel)
  └ Kubernetes privileged pod creation (Falco → Sentinel)

Incident response SLAs:
  P1 (payment breach, data exfiltration):  < 15 minutes
  P2 (cross-tenant access, fraud surge):   < 1 hour
  P3 (offline payment anomaly):            < 4 hours
  P4 (policy violation, config drift):     < 24 hours
```

---

## 7. Related Documents

| Document | Reference |
|---|---|
| TOGAF Security Architecture | `00_TOGAF/TOGAF_GlobalRetailPOS_EA_Document.md` — Page 11 |
| Payment Service LLD | `02_LLD/LLD-012_Payment_Service.md` |
| API Design LLD | `02_LLD/LLD-014_API_Design.md` |
| Tenant Provisioning LLD | `02_LLD/LLD-010_Tenant_Provisioning_Service.md` |
