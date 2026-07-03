# ADR-005 — ONNX Runtime for POS Edge AI Inference
## EnterpriseRetailAI · Architecture Decision Record

| ID | ADR-005 | Status | Approved | Date | 2026-02 | Decider | CDO + ARB |

---

## Context

POS terminals (Windows .NET and Android Java) must run real-time AI inference for fraud scoring (< 50ms p99) and promotion ranking (< 100ms p99) entirely locally, without network dependency.

---

## Decision

**ONNX Runtime** is the standard AI inference engine for all POS-device models.

All models (LightGBM fraud, gradient boost promo ranker) are exported to ONNX format with INT8 quantisation. Models are loaded at POS startup, hash-verified, and kept in memory for the shift duration.

---

## Rationale

| Criterion | ONNX Runtime | TensorFlow Lite | PyTorch Mobile |
|---|---|---|---|
| .NET 8 support | ✅ Native NuGet | ⚠️ C# bindings | ❌ None |
| Android Java/Kotlin | ✅ AAR package | ✅ Native | ⚠️ Limited |
| INT8 quantisation | ✅ First-class | ✅ | ⚠️ Limited |
| LightGBM → export | ✅ skl2onnx | ❌ | ❌ |
| Model size (fraud) | 4MB (INT8) | ~6MB | ~12MB |
| Inference latency p99 | 35ms | 48ms | 72ms |

---

## Consequences

**Positive:**
- Single model format across Windows + Android + Store Edge (Linux)
- Model training framework (LightGBM, PyTorch, sklearn) is irrelevant — all export to ONNX
- INT8 quantisation reduces model size 4× with < 2% accuracy impact
- SHA-256 hash verification at startup prevents tampered model loading

**Negative:**
- Not all ONNX opsets supported on older Android versions — floor: API 28+
- Dynamic-shape models require fixed-batch export (batch_size=1 for POS)
- Some PyTorch custom ops require manual ONNX custom operator registration

**Model Update Protocol:** Azure IoT Hub file upload → POS downloads on next restart → hash verified → loaded.
