# ADR-007 — P2PE Payment Tokenisation at POS
## EnterpriseRetailAI · Architecture Decision Record

| ID | ADR-007 | Status | Approved | Date | 2026-01 | Decider | CISO + CTO + ARB |

---

## Context

Payment card data (PAN) is the highest-risk data the platform handles. The architecture must meet PCI-DSS v4.0 requirements while minimising the scope of the Cardholder Data Environment (CDE) to reduce audit burden and annual compliance cost.

---

## Decision

**PCI SSC-validated P2PE (Point-to-Point Encryption)** solution is adopted.

Implementation:
- Hardware: Verifone P400 (Windows POS) and PAX A920 (Android POS) — both PCI SSC listed P2PE VPEDs
- Encryption: AES-128 DUKPT (Derived Unique Key Per Transaction) — key injected at manufacturing
- PAN never enters POS application memory or any application layer
- Only KSN (Key Serial Number) + encrypted ciphertext transmitted
- Decryption occurs at payment gateway (Adyen/Stripe) only

---

## Consequences

**Positive:**
- PCI-DSS scope reduced from SAQ D (full assessment) to SAQ P2PE (minimal)
- Estimated compliance cost saving: 70% reduction in annual PCI audit scope
- No cardholder data on store edge or cloud services — risk profile minimised
- Offline payments: HMAC-signed tokens never contain decrypted PAN

**Negative:**
- Hardware dependency: only Verifone/PAX validated VPEDs can be used
- Key injection at manufacturing adds 4-week lead time for new POS hardware
- P2PE solution renewal required every 3 years (PCI SSC programme)

**Risk:** If a non-P2PE device is inadvertently enrolled, full SAQ D scope applies immediately. Mitigation: IoT Hub device registry enforces device model whitelist at enrolment.
