# LLD-001 — POS Transaction Engine
## EnterpriseRetailAI · Detailed Design: Transaction Lifecycle, State Machine, Business Logic

---

| Document ID | LLD-001 | Type | Low-Level Design | Version | 1.0 |
| Status | Approved | Author | Platform Engineering | Date | June 2026 |

---

## 1. Purpose

This document provides the low-level design of the POS Transaction Engine — the core module responsible for managing the full lifecycle of a retail transaction from first item scan to receipt generation, including business rule application, tax computation, loyalty integration, and event persistence.

---

## 2. Service Design

### 2.1 Package Structure (Windows .NET 8)

```
RetailAI.POS.TransactionEngine/
├── Domain/
│   ├── Entities/
│   │   ├── Transaction.cs           # Aggregate root
│   │   ├── TransactionLine.cs       # Line item value object
│   │   ├── BasketTotals.cs          # Computed totals VO
│   │   ├── AppliedPromotion.cs      # Applied promo snapshot
│   │   └── PaymentRecord.cs         # Payment attempt record
│   ├── Events/
│   │   ├── TransactionCompletedEvent.cs
│   │   ├── TransactionVoidedEvent.cs
│   │   ├── LineAddedEvent.cs
│   │   └── PaymentProcessedEvent.cs
│   ├── Services/
│   │   ├── ITransactionService.cs
│   │   ├── IPricingService.cs
│   │   ├── IPromotionService.cs
│   │   ├── ITaxService.cs
│   │   └── ILoyaltyService.cs
│   └── StateMachine/
│       ├── TransactionStateMachine.cs
│       └── TransactionState.cs (enum)
├── Application/
│   ├── Commands/
│   │   ├── AddLineCommand.cs
│   │   ├── RemoveLineCommand.cs
│   │   ├── ApplyPromotionCommand.cs
│   │   ├── ProcessPaymentCommand.cs
│   │   ├── CompleteTransactionCommand.cs
│   │   └── VoidTransactionCommand.cs
│   ├── Handlers/           # MediatR command handlers
│   └── Validators/         # FluentValidation
├── Infrastructure/
│   ├── Persistence/
│   │   ├── SQLiteTransactionRepository.cs
│   │   ├── ProductCacheRepository.cs
│   │   └── EventOutboxRepository.cs
│   ├── External/
│   │   ├── StoreEdgeApiClient.cs
│   │   ├── PaymentTerminalClient.cs   # Verifone/PAX SDK wrapper
│   │   └── OnnxFraudScoringClient.cs
│   └── DependencyInjection/
│       └── ServiceCollectionExtensions.cs
└── Presentation/
    ├── WpfMainWindow.xaml / .cs
    └── ViewModels/
        ├── BasketViewModel.cs
        ├── PaymentViewModel.cs
        └── ReceiptViewModel.cs
```

---

## 3. Transaction Aggregate

```csharp
public class Transaction
{
    public Guid TransactionId { get; private set; }       // UUID v7 (time-sortable)
    public Guid TenantId     { get; private set; }
    public Guid StoreId      { get; private set; }
    public Guid PosId        { get; private set; }
    public Guid CashierId    { get; private set; }
    public TransactionState State { get; private set; }   // state machine
    public DateTime OpenedAt { get; private set; }
    public DateTime? CompletedAt { get; private set; }

    private readonly List<TransactionLine> _lines = new();
    public IReadOnlyList<TransactionLine> Lines => _lines.AsReadOnly();

    private readonly List<AppliedPromotion> _promotions = new();
    public IReadOnlyList<AppliedPromotion> AppliedPromotions => _promotions.AsReadOnly();

    private readonly List<IDomainEvent> _events = new();
    public IReadOnlyList<IDomainEvent> DomainEvents => _events.AsReadOnly();

    public BasketTotals Totals { get; private set; } = BasketTotals.Empty;

    public string? LoyaltyCustomerId { get; private set; }
    public string? IdempotencyKey    { get; private set; }   // UUID v4 — for sync dedup

    // State machine guard — all mutation goes through state checks
    public Result AddLine(TransactionLine line)
    {
        if (State != TransactionState.Scanning)
            return Result.Fail("Cannot add lines outside SCANNING state");

        _lines.Add(line);
        RecalculateTotals();
        _events.Add(new LineAddedEvent(TransactionId, line));
        return Result.Ok();
    }

    public Result RemoveLine(Guid lineId)
    {
        if (State != TransactionState.Scanning)
            return Result.Fail("Cannot remove lines outside SCANNING state");

        var line = _lines.FirstOrDefault(l => l.LineId == lineId)
                   ?? throw new DomainException($"Line {lineId} not found");
        _lines.Remove(line);
        RecalculateTotals();
        return Result.Ok();
    }

    public Result ApplyPromotion(AppliedPromotion promo)
    {
        if (State is not (TransactionState.Scanning or TransactionState.Totalling))
            return Result.Fail("Promotion cannot be applied in current state");

        // idempotency — same promo code not applied twice
        if (_promotions.Any(p => p.PromotionId == promo.PromotionId))
            return Result.Fail("Promotion already applied");

        _promotions.Add(promo);
        RecalculateTotals();
        return Result.Ok();
    }

    public Result TransitionToTotalling()
    {
        if (State != TransactionState.Scanning || !_lines.Any())
            return Result.Fail("Need at least one line to total");
        State = TransactionState.Totalling;
        return Result.Ok();
    }

    public Result TransitionToPaymentPending()
    {
        if (State != TransactionState.Totalling)
            return Result.Fail("Must be in TOTALLING to proceed to payment");
        State = TransactionState.PaymentPending;
        return Result.Ok();
    }

    public Result Complete(PaymentRecord payment)
    {
        if (State != TransactionState.PaymentPending)
            return Result.Fail("Invalid state for completion");

        State = TransactionState.Complete;
        CompletedAt = DateTime.UtcNow;
        IdempotencyKey = Guid.NewGuid().ToString(); // assigned at completion
        _events.Add(new TransactionCompletedEvent(this, payment));
        return Result.Ok();
    }

    public Result Void(Guid authorisedByManagerId, string reason)
    {
        if (State == TransactionState.Void)
            return Result.Fail("Already voided");
        if (State == TransactionState.Complete && CompletedAt < DateTime.UtcNow.AddSeconds(-300))
            return Result.Fail("Cannot void a transaction older than 5 minutes at POS");

        State = TransactionState.Void;
        _events.Add(new TransactionVoidedEvent(TransactionId, authorisedByManagerId, reason));
        return Result.Ok();
    }

    private void RecalculateTotals()
    {
        Totals = BasketTotalsCalculator.Calculate(_lines, _promotions);
    }
}
```

---

## 4. Transaction State Machine

```csharp
public enum TransactionState
{
    Idle,
    Scanning,
    Totalling,
    PaymentPending,
    Completing,
    Complete,
    Void,
    Suspended
}

// Valid transitions:
// Idle          → Scanning      (first item scanned)
// Scanning      → Totalling     (payment button pressed)
// Scanning      → Suspended     (hold basket)
// Totalling     → PaymentPending (payment confirmed)
// Totalling     → Scanning      (back to basket)
// PaymentPending → Completing   (payment approved)
// PaymentPending → Scanning     (payment declined)
// Completing    → Complete      (receipt issued)
// Scanning      → Void          (manager void, any time)
// PaymentPending → Void         (manager void)
// Suspended     → Scanning      (resume by basket ID)
```

---

## 5. Pricing & Tax Engine

```csharp
public class PricingService : IPricingService
{
    private readonly IProductCacheRepository _products;
    private readonly IPriceRuleRepository _priceRules;
    private readonly ITaxTableRepository _taxTables;

    public PricedLine Price(string barcode, int quantity, DateTime transactionTime)
    {
        var product = _products.GetByBarcode(barcode)
            ?? throw new ProductNotFoundException(barcode);

        // 1. Base price from local cache
        decimal unitPrice = product.BasePrice;

        // 2. Override: check for active price rule (time-limited prices)
        var rule = _priceRules.GetActiveRule(product.SkuId, transactionTime);
        if (rule != null)
            unitPrice = rule.OverridePrice;

        // 3. Tax computation (VAT / GST / Sales Tax)
        var taxRate = _taxTables.GetRate(product.TaxCategory, _posContext.Jurisdiction);
        decimal taxAmount = unitPrice * quantity * taxRate.Rate;

        // 4. Rounding: per-jurisdiction rounding rules (MidpointRounding.ToEven)
        taxAmount = Math.Round(taxAmount, taxRate.DecimalPlaces,
                               MidpointRounding.ToEven);

        return new PricedLine(product, quantity, unitPrice, taxRate, taxAmount);
    }
}
```

---

## 6. Promotion Engine

```csharp
public class PromotionService : IPromotionService
{
    private readonly IPromotionRuleRepository _rules;   // from SQLite cache
    private readonly IOnnxPromoRanker _onnxRanker;      // ONNX model (offline)
    private readonly IStoreEdgeApiClient _edgeApi;      // for online calls

    public async Task<IList<AppliedPromotion>> ResolveAsync(
        Transaction tx, CustomerContext? customer, bool onlineAvailable)
    {
        // 1. Get all rules applicable to basket (rule-based engine)
        var eligibleRules = _rules.GetEligibleRules(tx.Lines, tx.Totals,
                                                     DateTime.UtcNow);

        // 2. AI ranking — online: call Store Edge promo API
        //                 offline: ONNX ranker on device
        IList<RankedPromotion> ranked;
        if (onlineAvailable && customer != null)
        {
            ranked = await _edgeApi.RankPromotionsAsync(eligibleRules, tx, customer);
        }
        else
        {
            var features = FeatureExtractor.ExtractPromoFeatures(tx, customer, eligibleRules);
            ranked = _onnxRanker.Rank(features, eligibleRules);
        }

        // 3. Conflict resolution: mutually exclusive promos filtered
        var selected = PromoConflictResolver.SelectTop3(ranked);

        // 4. Apply and compute discount amounts
        return selected
            .Select(p => AppliedPromotion.From(p, tx))
            .ToList();
    }
}
```

---

## 7. Basket Totals Calculator

```csharp
public static class BasketTotalsCalculator
{
    public static BasketTotals Calculate(
        IReadOnlyList<TransactionLine> lines,
        IReadOnlyList<AppliedPromotion> promotions)
    {
        decimal subtotal      = lines.Sum(l => l.UnitPrice * l.Quantity);
        decimal taxTotal      = lines.Sum(l => l.TaxAmount);
        decimal promoDiscount = promotions.Sum(p => p.DiscountAmount);
        decimal grandTotal    = subtotal + taxTotal - promoDiscount;

        // Guard: total cannot go below zero (promo misconfiguration)
        grandTotal = Math.Max(0m, grandTotal);

        return new BasketTotals(subtotal, taxTotal, promoDiscount, grandTotal,
                                lines.Sum(l => l.Quantity));
    }
}
```

---

## 8. Event Outbox Persistence

```csharp
public class EventOutboxRepository : IEventOutboxRepository
{
    // SQLite schema: event_outbox
    // id TEXT PK, event_type TEXT, payload BLOB, created_at TEXT,
    // dispatched_at TEXT NULL, retry_count INTEGER DEFAULT 0

    public async Task SaveAsync(IDomainEvent domainEvent, IDbTransaction? txn = null)
    {
        var outboxEntry = new OutboxEntry
        {
            Id          = Guid.NewGuid().ToString(),
            EventType   = domainEvent.GetType().Name,
            Payload     = JsonSerializer.SerializeToUtf8Bytes(domainEvent),
            CreatedAt   = DateTime.UtcNow.ToString("O"),
            RetryCount  = 0
        };

        // Written in same SQLite transaction as the domain state change.
        // Guarantees: event saved if and only if transaction committed.
        await _db.ExecuteAsync(
            @"INSERT INTO event_outbox (id, event_type, payload, created_at, retry_count)
              VALUES (@Id, @EventType, @Payload, @CreatedAt, @RetryCount)",
            outboxEntry, transaction: txn);
    }

    public async Task<IList<OutboxEntry>> GetPendingAsync(int batchSize = 100)
    {
        return (await _db.QueryAsync<OutboxEntry>(
            @"SELECT * FROM event_outbox
              WHERE dispatched_at IS NULL
              ORDER BY created_at ASC
              LIMIT @batchSize",
            new { batchSize })).ToList();
    }

    public async Task MarkDispatchedAsync(string id)
    {
        await _db.ExecuteAsync(
            "UPDATE event_outbox SET dispatched_at = @Now WHERE id = @Id",
            new { Now = DateTime.UtcNow.ToString("O"), Id = id });
    }
}
```

---

## 9. Loyalty Integration

```csharp
public class LoyaltyService : ILoyaltyService
{
    // Points accrual written to SQLite loyalty_delta table offline,
    // replayed to cloud Loyalty Service on reconnect.

    public async Task AccrueAsync(
        Guid customerId, Guid transactionId, decimal transactionTotal)
    {
        int pointsEarned = (int)Math.Floor(transactionTotal * _ruleConfig.PointsPerUnit);

        var delta = new LoyaltyDelta
        {
            DeltaId       = Guid.NewGuid(),
            CustomerId    = customerId,
            TransactionId = transactionId,
            PointsEarned  = pointsEarned,
            Timestamp     = DateTime.UtcNow
        };

        await _repo.SaveDeltaAsync(delta);   // SQLite offline store
        _outbox.Enqueue(new LoyaltyAccruedEvent(delta)); // outbox for sync
    }

    public async Task<int> GetBalanceAsync(Guid customerId, bool preferOnline = true)
    {
        if (preferOnline && _connectivity.IsOnline)
        {
            try {
                return await _edgeApi.GetLoyaltyBalanceAsync(customerId);
            } catch { /* fall through */ }
        }

        // Offline: return cached balance + pending deltas
        int cached  = await _repo.GetCachedBalanceAsync(customerId);
        int pending = await _repo.GetPendingDeltaSumAsync(customerId);
        return cached + pending;
    }
}
```

---

## 10. Shift Management

```csharp
public record ShiftRecord(
    Guid    ShiftId,
    Guid    CashierId,
    Guid    PosId,
    decimal OpeningFloat,
    DateTime OpenedAt,
    decimal? ClosingFloat,
    DateTime? ClosedAt,
    ShiftSummary? Summary   // generated at EOD
);

public class ShiftSummary
{
    public int TransactionCount   { get; init; }
    public decimal GrossSales     { get; init; }
    public decimal DiscountsGiven { get; init; }
    public decimal TaxCollected   { get; init; }
    public decimal NetSales       { get; init; }
    public decimal CashExpected   { get; init; }
    public decimal CashActual     { get; init; }
    public decimal Variance       { get; init; }
    public int VoidCount          { get; init; }
    public int ReturnCount        { get; init; }
    public IDictionary<string, decimal> SalesByTender { get; init; } = new();
}
// End-of-shift summary written to SQLite shifts table + outbox for cloud sync
```

---

## 11. Error Handling Strategy

| Error Type | Handler | User Action |
|---|---|---|
| ProductNotFoundException | Log + alert cashier | Re-scan or manual entry |
| PaymentDeclinedException | Log + return to TOTALLING | Offer alternative payment |
| StorageException (SQLite) | Retry 3× then alert manager | Contact IT support |
| StoreEdgeTimeout | Switch to offline mode automatically | None (transparent) |
| OnnxInferenceException | Fallback to rule-based scoring | Log + alert silently |
| PromoRuleConflict | Remove lowest-priority conflicting promo | None (transparent) |
| ShiftNotOpenException | Prompt cashier to open shift | Open shift |

---

## 12. Performance Targets

| Operation | Target | Measured On |
|---|---|---|
| Barcode lookup (SQLite cache) | < 50ms (p99) | Reference POS hardware |
| Basket total recalculation | < 20ms | Any basket size |
| Promo resolution (ONNX) | < 100ms | 20 eligible promos |
| Fraud score (ONNX) | < 50ms | 35-feature vector |
| Transaction complete + outbox write | < 200ms | SQLite write |
| SQLite → Store Edge sync (single event) | < 5s | LAN 100Mbps |

---

## 13. Configuration

```json
{
  "TransactionEngine": {
    "MaxBasketLines": 500,
    "MaxLineQuantity": 9999,
    "OfflineTimeoutSeconds": 30,
    "OutboxBatchSize": 100,
    "OutboxRelayIntervalMs": 2000,
    "OutboxRetryMaxAttempts": 10,
    "OutboxRetryBaseDelayMs": 500,
    "SuspendedBasketTtlMinutes": 60,
    "VoidWindowSeconds": 300,
    "LoyaltyPointsPerUnitGbp": 1,
    "FraudScoreThresholdAllow": 0.40,
    "FraudScoreThresholdDecline": 0.70,
    "OnnxFraudModelPath": "/models/fraud_detection_v{version}.onnx",
    "OnnxPromoModelPath": "/models/promotion_ranker_v{version}.onnx"
  }
}
```

---

## 14. Observability

| Signal | Tool | Metric Name |
|---|---|---|
| Transaction throughput | App Insights | `pos.transactions.per_minute` |
| Payment success rate | App Insights | `pos.payment.success_rate` |
| Fraud score distribution | App Insights histogram | `pos.fraud.score` |
| Outbox queue depth | Prometheus (POS agent) | `pos.outbox.queue_depth` |
| ONNX inference latency | App Insights | `pos.onnx.inference_ms` |
| Offline mode active | App Insights | `pos.mode.offline_active` |
| Shift variance | App Insights | `pos.shift.cash_variance_gbp` |

---

## 15. Related Documents

| Document | Reference |
|---|---|
| POS Application HLD | `01_HLD/HLD-002_POS_Application.md` |
| Offline Sync Agent LLD | `02_LLD/LLD-002_Offline_Sync_Agent.md` |
| Payment Service LLD | `02_LLD/LLD-012_Payment_Service.md` |
| Fraud Detection LLD | `02_LLD/LLD-004_Fraud_Detection_Service.md` |
| Data Schema LLD | `02_LLD/LLD-013_Data_Schema_Design.md` |
