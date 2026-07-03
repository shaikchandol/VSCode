# LLD-012 — Payment Service
## EnterpriseRetailAI · Online/Offline Payment, P2PE, Token Engine, Settlement

---

| Document ID | LLD-012 | Version | 1.0 | Status | Approved |

---

## 1. Payment Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                     PAYMENT ARCHITECTURE                            │
│                                                                      │
│  POS Terminal (P2PE scope)                                           │
│  ├── Card presented → HSM encrypts PAN (never in app memory)        │
│  └── Encrypted payload → Store Edge → Azure Payment Service         │
│                                                                      │
│  ONLINE FLOW:                                                        │
│  P2PE payload ──► Store Edge ──► APIM ──► Payment Service           │
│                                              │                       │
│                                         Payment Gateway             │
│                                       (Adyen / Stripe)              │
│                                              │                       │
│                                    Approved ─┤─ Declined            │
│                                                                      │
│  OFFLINE FLOW:                                                       │
│  P2PE payload ──► Offline Token Engine                               │
│                         │                                            │
│              Within ceiling? ─ YES → Token stored locally           │
│              Within ceiling? ─ NO  → Decline / Manager override     │
│                         │                                            │
│              On reconnect → Token settlement batch                  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. P2PE Implementation

```
P2PE Standard: PCI SSC P2PE validated solution
Hardware: Verifone P400 / PAX A920 (validated PIN entry devices — VPEDs)

Encryption: AES-128 DUKPT (Derived Unique Key Per Transaction)
  DUKPT key management:
  - Initial PIN Encryption Key (IPEK) injected at device manufacturing
  - Per-transaction key derived from IPEK + KSN (Key Serial Number)
  - Encrypted track data + KSN transmitted to decryption service (POI)

PAN data flow:
  Card → VPED hardware → HSM encrypts (KSN + encrypted PAN)
  → Encrypted blob → Application layer (PAN never in plaintext)
  → Store Edge → APIM → Payment Service → Decryption Point of Interaction
  → Adyen/Stripe (receives KSN + encrypted PAN, decrypts internally)

Scope reduction: P2PE listing reduces PCI-DSS scope to SAQ P2PE
```

---

## 3. Online Payment Flow (.NET 8)

```csharp
public class PaymentService : IPaymentService
{
    private readonly IAdyenClient _adyenClient;
    private readonly IPaymentRepository _repo;
    private readonly IEventOutbox _outbox;

    public async Task<PaymentResult> ProcessOnlineAsync(
        PaymentRequest request,
        CancellationToken ct = default)
    {
        // Request contains: KSN, encrypted_pan, amount, currency, terminal_id
        // PAN is NEVER decrypted or touched in this service

        var gatewayRequest = new AdyenPaymentRequest
        {
            MerchantAccount = request.TenantMerchantId,
            Amount          = new Amount(request.Currency, request.AmountMinor),
            EncryptedCardNumber = request.EncryptedPAN,
            KeySerialNumber = request.KSN,
            Reference       = request.IdempotencyKey,
            AdditionalData  = new Dictionary<string, string>
            {
                ["riskdata.device.fingerprint"] = request.DeviceFingerprint,
                ["authorisationType"]            = "PreAuth",
            },
        };

        try
        {
            var response = await _adyenClient.PaymentsAsync(gatewayRequest, ct);

            var result = response.ResultCode switch
            {
                ResultCodeEnum.Authorised => PaymentResult.Approved(response.PspReference,
                                                                      response.AuthCode),
                ResultCodeEnum.Refused    => PaymentResult.Declined(response.RefusalReason),
                ResultCodeEnum.Error      => PaymentResult.Error(response.Message),
                _                         => PaymentResult.Pending(response.PspReference),
            };

            // Persist payment record
            await _repo.SaveAsync(new PaymentRecord
            {
                PaymentId      = Guid.NewGuid(),
                TenantId       = request.TenantId,
                TransactionId  = request.TransactionId,
                PaymentMethod  = request.PaymentMethod,
                AmountMinor    = request.AmountMinor,
                Currency       = request.Currency,
                TokenReference = response.PspReference,
                AuthCode       = response.AuthCode,
                IsOffline      = false,
                Status         = result.IsApproved ? "APPROVED" : "DECLINED",
            }, ct);

            // Publish payment event to outbox
            await _outbox.EnqueueAsync(new PaymentProcessedEvent(request, result), ct);

            return result;
        }
        catch (AdyenApiException ex) when (ex.IsNetworkError)
        {
            // Network error — switch to offline token engine
            return await ProcessOfflineAsync(request, ct);
        }
    }
```

---

## 4. Offline Token Engine

```csharp
public class OfflineTokenEngine : IOfflinePaymentEngine
{
    private readonly IOfflineTokenRepository _tokenRepo;
    private readonly IOfflineCeilingConfig _ceiling;  // HQ-signed, TPM-stored
    private readonly IHmacKeyProvider _hmacKeys;

    public async Task<OfflineTokenResult> CreateTokenAsync(
        OfflinePaymentRequest request)
    {
        // 1. Validate within HQ-signed ceiling config
        var ceilingConfig = await _ceiling.GetAsync();

        if (!ceilingConfig.IsValidSignature())
            return OfflineTokenResult.Fail("Ceiling config signature invalid — contact HQ");

        if (request.AmountMinor > ceilingConfig.PerTransactionCeilingMinor)
            return OfflineTokenResult.Fail(
                $"Amount exceeds offline ceiling of {ceilingConfig.PerTransactionCeilingMinor / 100m:C}");

        if (!ceilingConfig.AllowedCardTypes.Contains(request.CardType))
            return OfflineTokenResult.Fail($"Card type {request.CardType} not allowed offline");

        // 2. Check cumulative shift ceiling
        var shiftTotal = await _tokenRepo.GetShiftOfflineTotalAsync(request.ShiftId);
        if (shiftTotal + request.AmountMinor > ceilingConfig.PerShiftCeilingMinor)
            return OfflineTokenResult.Fail("Shift offline ceiling reached");

        // 3. Generate HMAC-signed token
        var nonce    = GenerateCryptoNonce(16);
        var expiry   = DateTime.UtcNow.AddHours(72);
        var hmacKey  = await _hmacKeys.GetDeviceKeyAsync(request.DeviceId);

        var tokenPayload = new OfflineTokenPayload
        {
            TokenId      = Guid.NewGuid(),
            DeviceId     = request.DeviceId,
            MerchantId   = request.MerchantId,
            MaskedPAN    = MaskPAN(request.CardToken),
            AmountMinor  = request.AmountMinor,
            Currency     = request.Currency,
            Timestamp    = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
            Expiry       = expiry,
            Nonce        = Convert.ToBase64String(nonce),
        };

        var hmac = ComputeHmacSha256(
            JsonSerializer.Serialize(tokenPayload), hmacKey);

        var signedToken = new OfflineToken
        {
            TokenId     = tokenPayload.TokenId,
            Payload     = tokenPayload,
            Hmac        = Convert.ToBase64String(hmac),
            Status      = "PENDING",
            CreatedAt   = DateTime.UtcNow,
            ExpiryAt    = expiry,
        };

        // 4. Persist (AES-256 encrypted in SQLite)
        await _tokenRepo.SaveAsync(signedToken);

        return OfflineTokenResult.Success(signedToken.TokenId, expiry);
    }

    private static string MaskPAN(string cardToken)
    {
        // cardToken from P2PE metadata — already a masked reference, not PAN
        // e.g. "4111 **** **** 1111"
        return cardToken.Length > 8 ? cardToken[..6] + "****" + cardToken[^4..] : "****";
    }

    private static byte[] GenerateCryptoNonce(int length)
    {
        var nonce = new byte[length];
        System.Security.Cryptography.RandomNumberGenerator.Fill(nonce);
        return nonce;
    }
}
```

---

## 5. Token Settlement Service (AKS)

```csharp
public class TokenSettlementService : BackgroundService
{
    // Runs on reconnect; processes all PENDING offline tokens within 72h window

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        await foreach (var batch in _tokenQueue.ReadAllAsync(ct))
        {
            foreach (var token in batch)
            {
                try
                {
                    // Validate token not expired
                    if (token.ExpiryAt < DateTime.UtcNow)
                    {
                        await _repo.UpdateStatusAsync(token.TokenId, "EXPIRED");
                        await _alerts.SendExpiryAlertAsync(token);
                        continue;
                    }

                    // Validate HMAC integrity
                    if (!ValidateTokenHmac(token))
                    {
                        await _repo.UpdateStatusAsync(token.TokenId, "TAMPERED");
                        await _security.RaiseSecurityAlertAsync(token);
                        continue;
                    }

                    // Submit to payment gateway for settlement
                    var settlementResult = await _gateway.SettleOfflineAsync(
                        new OfflineSettlementRequest
                        {
                            MerchantAccount  = token.Payload.MerchantId,
                            Amount           = token.Payload.AmountMinor,
                            Currency         = token.Payload.Currency,
                            OfflineTokenRef  = token.TokenId.ToString(),
                            OriginalDateTime = token.Payload.Timestamp,
                        });

                    var status = settlementResult.IsSuccess ? "SETTLED" : "FAILED";
                    await _repo.UpdateStatusAsync(token.TokenId, status,
                                                   settlementResult.GatewayRef);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Token settlement failed for {TokenId}", token.TokenId);
                    await _repo.IncrementRetryAsync(token.TokenId);
                    // Retry up to 3 times before marking FAILED
                }
            }
        }
    }
}
```

---

## 6. Payment Method Support Matrix

| Method | Online Auth | Offline Token | Ceiling Enforced | Notes |
|---|---|---|---|---|
| EMV Chip + PIN | ✅ Real-time | ✅ HMAC token | ✅ Per-tx + per-shift | Primary card method |
| Contactless NFC (card) | ✅ | ✅ | ✅ | Apple Pay, Google Pay |
| Contactless NFC (device) | ✅ | ✅ | ✅ | Samsung Pay, etc. |
| QR Code | ✅ | ❌ | — | Requires live validation |
| MSR (magnetic swipe) | ✅ | ❌ | — | Blocked offline (fraud risk) |
| Cash | ✅ | ✅ (no token needed) | — | Cash drawer only |
| Gift Card | ✅ | ✅ (pre-loaded balance) | ✅ | Balance synced on reconnect |
| Split Payment | ✅ | ✅ (combined ceiling) | ✅ | Any combination |

---

## 7. Settlement Flow & Reconciliation

```
End of Day / On Reconnect:
    │
Payment Service polls offline_payment_tokens WHERE status = 'PENDING'
    │
Batch settlement request → Adyen/Stripe batch settlement API
    │
    ├── Settled → status = 'SETTLED', settled_at = now()
    ├── Failed  → status = 'FAILED', retry_count++
    └── Expired → status = 'EXPIRED', alert raised
    │
Reconciliation report:
  - Total offline tokens: count, value
  - Settled successfully: count, value
  - Failed/expired: count, value, manual review required
  - Settlement completion rate: must be 100% within 72h
```

---

## 8. Security Controls

| Control | Implementation |
|---|---|
| PAN never in application | P2PE HSM encrypts at card tap; KSN+ciphertext only in transit |
| DUKPT key management | Validated VPED injects IPEK at factory; per-tx derived key |
| Offline token integrity | HMAC-SHA256 with device key (TPM-stored, non-exportable) |
| Token expiry | 72-hour hard expiry; server-side validation before settlement |
| Ceiling enforcement | HQ-signed JSON config; RSA-PSS signature verified against HQ public key |
| Offline ceiling config tamper | TPM Secure Enclave stores config; hash verified at startup |
| Settlement encryption | All tokens encrypted AES-256 at rest (SQLite + Azure SQL) |
| PCI-DSS scope | P2PE listed solution; see LLD-007 Security for scope diagram |

---

## 9. Related Documents

- HLD-002: POS Application (payment flow overview)
- HLD-007: Security and Compliance (PCI-DSS controls)
- LLD-001: POS Transaction Engine (payment integration)
- LLD-013: Data Schema Design (payment tables DDL)

