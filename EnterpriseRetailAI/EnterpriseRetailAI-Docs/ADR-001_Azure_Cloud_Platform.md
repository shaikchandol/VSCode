# ADR-001 — Azure as Primary Cloud Platform
## EnterpriseRetailAI · Architecture Decision Record

| ID | ADR-001 | Status | Approved | Date | 2026-01 | Decider | CTO + ARB |

---

## Context

EnterpriseRetailAI requires a cloud platform to host:
- Multi-tenant AKS microservice clusters (one namespace per franchisee)
- AI/ML training and inference (Azure ML + Azure OpenAI)
- IoT device management for 50,000+ POS terminals and store edge nodes
- Globally distributed event streaming with per-tenant isolation
- Compliance with PCI-DSS, GDPR, DPDP, PIPL, CCPA simultaneously

Three cloud providers were evaluated: **Azure**, AWS, and GCP.

---

## Options Considered

### Option A: Microsoft Azure ✅ (Selected)
- Azure OpenAI Service: enterprise-grade GPT-4o with data residency guarantees
- Azure IoT Hub + IoT Edge: native OTA model deployment to edge devices
- AKS + Azure APIM: proven multitenant isolation patterns
- Azure Policy: regulatory compliance enforcement per region
- Existing enterprise agreement with negotiated pricing
- Microsoft Sentinel: integrated SIEM with Defender for Endpoint

### Option B: AWS
- SageMaker for ML — mature but no native IoT Edge model deployment
- Greengrass for edge — less mature than Azure IoT Edge for retail
- No equivalent to Azure OpenAI (Bedrock lacks enterprise data residency SLAs)
- Separate PCI tooling required

### Option C: GCP
- Vertex AI — strong ML, weak IoT edge story
- No native NLP equivalent to Azure OpenAI at enterprise SLA
- Smaller enterprise retail reference architecture base
- Anthos for hybrid — more complex for store edge deployment

---

## Decision

**Azure** is selected as the primary cloud platform.

Key deciding factors:
1. Azure OpenAI provides GPT-4o with data residency commitments (GDPR-compliant)
2. Azure IoT Edge is the most mature solution for OTA AI model deployment to store edge
3. Existing enterprise agreement provides 30% cost reduction vs. list pricing
4. Azure APIM + AKS has proven multitenant patterns with per-namespace isolation
5. Microsoft Defender suite covers all tiers (cloud, edge, endpoint) in one console

---

## Consequences

**Positive:**
- Single vendor for AI, IoT, compute, security — reduces integration complexity
- Azure-native RBAC, managed identities, Key Vault used across all services
- Compliance controls built into Azure Policy — no custom tooling required

**Negative:**
- Vendor lock-in risk: mitigation = containerise all workloads (K3s, ONNX, Avro)
- Azure China (21Vianet) is a separate entity requiring separate configuration
- Azure OpenAI quota limits may constrain NLP assistant in peak scenarios

**Mitigations:**
- All AI models trained in ONNX format (portable to any runtime)
- All data schemas in Avro (cloud-agnostic)
- Multi-cloud exit strategy documented in runbook
