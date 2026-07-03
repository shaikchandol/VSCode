# DAPR Integration for Microservices Communication

## Overview

**DAPR** (Distributed Application Runtime) provides resilient, cloud-agnostic service-to-service communication, state management, and pub/sub messaging replacing direct database access with distributed patterns.

## Project Structure

```
Dapr/
├── BookRatings.Dapr.Core/
│   ├── ServiceInvocation/
│   │   ├── DaprServiceClient.cs         # Service-to-service calls
│   │   ├── DaprServiceRegistry.cs       # Service discovery
│   │   ├── InvocationPolicy.cs          # Retry/timeout policies
│   │   └── DaprInvocationMiddleware.cs  # Request enrichment
│   │
│   ├── StateManagement/
│   │   ├── DaprStateStore.cs            # State storage abstraction
│   │   ├── StateStoreProvider.cs        # Redis/Cosmos state backend
│   │   ├── OptimisticConcurrency.cs     # Concurrency handling
│   │   └── StateTransactionManager.cs   # ACID transactions
│   │
│   ├── PubSub/
│   │   ├── DaprPublisher.cs             # Event publishing
│   │   ├── DaprSubscriber.cs            # Event subscription
│   │   ├── TopicRouter.cs               # Route events to handlers
│   │   └── DeadLetterQueue.cs           # Handle failed messages
│   │
│   ├── Secrets/
│   │   ├── DaprSecretsStore.cs          # Secrets retrieval
│   │   ├── LocalSecretsProvider.cs      # Local development
│   │   └── VaultIntegration.cs          # Production vault
│   │
│   ├── Configuration/
│   │   ├── DaprConfiguration.cs         # DAPR setup
│   │   ├── ComponentRegistry.yaml       # Component definitions
│   │   └── ResiliencyPolicy.yaml        # Resilience rules
│   │
│   └── Observability/
│       ├── DaprTracing.cs               # Distributed tracing
│       ├── DaprMetrics.cs               # Metrics collection
│       └── DaprHealthChecks.cs          # Health monitoring
│
├── components/
│   ├── statestore.yaml                  # State management
│   ├── pubsub.yaml                      # Pub/Sub broker
│   ├── secrets.yaml                     # Secrets store
│   ├── bindings.yaml                    # Input/output bindings
│   └── resiliency.yaml                  # Resilience policies
│
├── BookRatings.Dapr.Tests/
│   ├── ServiceInvocationTests.cs
│   ├── StateManagementTests.cs
│   ├── PubSubTests.cs
│   └── docker-compose.dapr.yml
│
└── README.md
```

## DAPR Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Books Service                                           │
│  ┌────────────────────────────────────────────────┐    │
│  │ Application Code                               │    │
│  │  (Uses DaprServiceClient, DaprStateStore)     │    │
│  └──────────────┬─────────────────────────────────┘    │
│                 │ HTTP/gRPC                            │
│  ┌──────────────▼─────────────────────────────────┐    │
│  │ DAPR Sidecar (Port 3500/50001)                │    │
│  │  - Service Invocation                          │    │
│  │  - State Management                            │    │
│  │  - Pub/Sub                                     │    │
│  └──────────────┬─────────────────────────────────┘    │
└─────────────────┼──────────────────────────────────────┘
                  │
    ┌─────────────┼──────────────┐
    │             │              │
    ▼             ▼              ▼
┌────────┐  ┌─────────┐  ┌──────────────┐
│ Redis  │  │RabbitMQ │  │Service Mesh  │
│ State  │  │ Pub/Sub │  │(Istio/Linkerd)
└────────┘  └─────────┘  └──────────────┘
```

## DAPR Components Configuration

### statestore.yaml

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: bookratings-statestore
  namespace: dapr-system
spec:
  type: state.redis
  version: v1
  metadata:
  - name: redisHost
    value: redis:6379
  - name: redisPassword
    value: ""
  - name: actorStateStore
    value: "true"
  - name: ttlInSeconds
    value: "3600"
  scopes:
  - books-service
  - ratings-service
  - users-service
  - admin-service
  - reporting-service
```

### pubsub.yaml

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: bookratings-pubsub
  namespace: dapr-system
spec:
  type: pubsub.rabbitmq
  version: v1
  metadata:
  - name: host
    value: amqp://guest:guest@rabbitmq:5672
  - name: durable
    value: "true"
  - name: maxRetries
    value: "5"
  - name: retryInterval
    value: "1s"
  scopes:
  - books-service
  - ratings-service
  - users-service
  - admin-service
  - reporting-service
```

### resiliency.yaml

```yaml
apiVersion: dapr.io/v1alpha1
kind: Resiliency
metadata:
  name: bookratings-resiliency
  namespace: dapr-system
spec:
  policies:
    timeouts:
      general: 5s
      long: 30s
    retries:
      general:
        maxRetries: 3
        backoffPolicy: exponential
        initialInterval: 1s
      longOp:
        maxRetries: 5
        backoffPolicy: exponential
        initialInterval: 2s
    circuitBreakers:
      general:
        interval: 30s
        maxRequests: 100
        consecutiveErrors: 5
        timeout: 60s
  targets:
    services:
      books-service:
        timeout: general
        retry: general
        circuitBreaker: general
      ratings-service:
        timeout: general
        retry: general
        circuitBreaker: general
      users-service:
        timeout: general
        retry: general
        circuitBreaker: general
    apps:
      bookratings-statestore:
        timeout: general
        retry: general
        circuitBreaker: general
      bookratings-pubsub:
        timeout: longOp
        retry: longOp
        circuitBreaker: general
```

## Service Invocation

### DaprServiceClient.cs

```csharp
public class DaprServiceClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<DaprServiceClient> _logger;
    private const string DaprEndpoint = "http://localhost:3500";

    public DaprServiceClient(HttpClient httpClient, ILogger<DaprServiceClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<T> InvokeServiceAsync<T>(
        string serviceName,
        string methodName,
        object? request = null,
        string httpMethod = "POST",
        CancellationToken cancellationToken = default)
    {
        try
        {
            var url = $"{DaprEndpoint}/v1.0/invoke/{serviceName}/method/{methodName}";
            
            HttpResponseMessage response;
            
            if (httpMethod == "GET")
            {
                response = await _httpClient.GetAsync(url, cancellationToken);
            }
            else if (httpMethod == "POST" && request != null)
            {
                var content = new StringContent(
                    JsonConvert.SerializeObject(request),
                    Encoding.UTF8,
                    "application/json");
                response = await _httpClient.PostAsync(url, content, cancellationToken);
            }
            else
            {
                throw new ArgumentException($"Unsupported HTTP method: {httpMethod}");
            }

            response.EnsureSuccessStatusCode();

            var jsonContent = await response.Content.ReadAsStringAsync(cancellationToken);
            var result = JsonConvert.DeserializeObject<T>(jsonContent);

            _logger.LogInformation(
                "Service invocation successful: {ServiceName}.{MethodName}",
                serviceName, methodName);

            return result!;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex,
                "Service invocation failed: {ServiceName}.{MethodName}",
                serviceName, methodName);
            throw;
        }
    }
}
```

### Example: Books Service calling Ratings Service

```csharp
[HttpGet("{id}")]
public async Task<IResult> GetBookWithRatings(
    int id,
    DaprServiceClient daprClient,
    CancellationToken ct)
{
    // Get book
    var book = await _repository.GetByIdAsync(id);

    // Invoke Ratings Service via DAPR
    var ratings = await daprClient.InvokeServiceAsync<RatingStatsDto>(
        serviceName: "ratings-service",
        methodName: "stats",
        request: new { BookId = id },
        cancellationToken: ct);

    return Results.Ok(new
    {
        book = book,
        ratings = ratings
    });
}
```

## State Management

### DaprStateStore.cs

```csharp
public class DaprStateStore
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<DaprStateStore> _logger;
    private const string DaprEndpoint = "http://localhost:3500";

    public DaprStateStore(HttpClient httpClient, ILogger<DaprStateStore> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task SaveStateAsync<T>(
        string storeName,
        string key,
        T value,
        string? etag = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var url = $"{DaprEndpoint}/v1.0/state/{storeName}";
            
            var stateItem = new
            {
                key = key,
                value = value,
                etag = etag,
                options = new { concurrency = "first-write" }
            };

            var content = new StringContent(
                JsonConvert.SerializeObject(new[] { stateItem }),
                Encoding.UTF8,
                "application/json");

            var response = await _httpClient.PostAsync(url, content, cancellationToken);
            response.EnsureSuccessStatusCode();

            _logger.LogInformation(
                "State saved: {StoreName}/{Key}",
                storeName, key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to save state: {StoreName}/{Key}",
                storeName, key);
            throw;
        }
    }

    public async Task<(T? Value, string? Etag)> GetStateAsync<T>(
        string storeName,
        string key,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var url = $"{DaprEndpoint}/v1.0/state/{storeName}/{key}";
            
            var response = await _httpClient.GetAsync(url, cancellationToken);
            response.EnsureSuccessStatusCode();

            var jsonContent = await response.Content.ReadAsStringAsync(cancellationToken);
            var value = JsonConvert.DeserializeObject<T>(jsonContent);

            var etag = response.Headers.ETag?.Tag;

            _logger.LogInformation(
                "State retrieved: {StoreName}/{Key}",
                storeName, key);

            return (value, etag);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to retrieve state: {StoreName}/{Key}",
                storeName, key);
            throw;
        }
    }

    public async Task DeleteStateAsync(
        string storeName,
        string key,
        string? etag = null,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var url = $"{DaprEndpoint}/v1.0/state/{storeName}/{key}";
            
            var request = new HttpRequestMessage(HttpMethod.Delete, url);
            if (!string.IsNullOrEmpty(etag))
            {
                request.Headers.Add("If-Match", etag);
            }

            var response = await _httpClient.SendAsync(request, cancellationToken);
            response.EnsureSuccessStatusCode();

            _logger.LogInformation(
                "State deleted: {StoreName}/{Key}",
                storeName, key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to delete state: {StoreName}/{Key}",
                storeName, key);
            throw;
        }
    }
}
```

## Pub/Sub Messaging

### DaprPublisher.cs

```csharp
public class DaprPublisher
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<DaprPublisher> _logger;
    private const string DaprEndpoint = "http://localhost:3500";

    public DaprPublisher(HttpClient httpClient, ILogger<DaprPublisher> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task PublishEventAsync<T>(
        string topicName,
        T eventData,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var url = $"{DaprEndpoint}/v1.0/publish/bookratings-pubsub/{topicName}";
            
            var content = new StringContent(
                JsonConvert.SerializeObject(eventData),
                Encoding.UTF8,
                "application/json");

            var response = await _httpClient.PostAsync(url, content, cancellationToken);
            response.EnsureSuccessStatusCode();

            _logger.LogInformation(
                "Event published: Topic={TopicName}, Event={EventType}",
                topicName, typeof(T).Name);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to publish event: Topic={TopicName}",
                topicName);
            throw;
        }
    }
}

// Usage in handler
public class CreateBookHandler : IRequestHandler<CreateBookRequest, CreateBookResponse>
{
    private readonly DaprPublisher _publisher;

    public async Task<CreateBookResponse> Handle(CreateBookRequest request, CancellationToken ct)
    {
        var book = new Book { Title = request.Title, Author = request.Author };
        await _repository.AddAsync(book);

        // Publish via DAPR instead of MassTransit
        await _publisher.PublishEventAsync("book-created", new BookCreatedEvent
        {
            BookId = book.Id,
            Title = book.Title,
            Author = book.Author
        }, ct);

        return new CreateBookResponse { Id = book.Id };
    }
}
```

### DaprSubscriber.cs (Endpoint Registration)

```csharp
// In Program.cs
app.MapPost("/dapr/subscribe", async (HttpContext context, DaprPublisher publisher) =>
{
    return Results.Ok(new
    {
        pubsubname = "bookratings-pubsub",
        topic = "book-created",
        routes = new
        {
            rules = new object[]
            {
                new { match = @"event.type == 'com.example.BookCreatedEvent'", endpoint = "/events/book-created" }
            }
        }
    });
});

app.MapPost("/events/book-created", async (BookCreatedEvent @event) =>
{
    // Handle BookCreatedEvent
    // This endpoint is called automatically by DAPR when event is published
    return Results.Ok();
});
```

## Configuration in Program.cs

```csharp
// Register DAPR services
builder.Services.AddScoped<DaprServiceClient>();
builder.Services.AddScoped<DaprStateStore>();
builder.Services.AddScoped<DaprPublisher>();

// Add DAPR health checks
builder.Services.AddHealthChecks()
    .AddCheck<DaprHealthCheck>("dapr-health");

// Configure HTTP client with DAPR endpoint
builder.Services.AddHttpClient<DaprServiceClient>()
    .ConfigureHttpClient(client =>
    {
        client.BaseAddress = new Uri("http://localhost:3500");
        client.Timeout = TimeSpan.FromSeconds(30);
    });

// Add distributed context propagation
builder.Services.AddScoped<DaprInvocationMiddleware>();

app.UseMiddleware<DaprInvocationMiddleware>();
```

## Running with DAPR

```bash
# Install DAPR CLI
curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash

# Initialize DAPR (first time)
dapr init

# Start service with DAPR sidecar
dapr run --app-id books-service \
  --app-port 5001 \
  --dapr-http-port 3500 \
  --dapr-grpc-port 50001 \
  --components-path ./dapr/components \
  dotnet run --project Services/Books/BookRatings.Services.Books/

# Start Ratings Service on different ports
dapr run --app-id ratings-service \
  --app-port 5002 \
  --dapr-http-port 3501 \
  --dapr-grpc-port 50002 \
  --components-path ./dapr/components \
  dotnet run --project Services/Ratings/BookRatings.Services.Ratings/
```

## Docker Compose with DAPR

```yaml
version: '3.8'

services:
  books-service:
    build:
      context: Services/Books
      dockerfile: Dockerfile
    environment:
      DAPR_HTTP_PORT: "3500"
      DAPR_GRPC_PORT: "50001"
    ports:
      - "5001:5001"

  dapr-books-sidecar:
    image: daprio/dapr:latest
    command: ["./daprd", "-app-id", "books-service", "-app-port", "5001", "-http-port", "3500", "-grpc-port", "50001"]
    environment:
      DAPR_COMPONENTS_PATH: /components
    ports:
      - "3500:3500"
      - "50001:50001"
    volumes:
      - ./dapr/components:/components
    depends_on:
      - books-service
      - redis
      - rabbitmq

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  rabbitmq:
    image: rabbitmq:3.12-management
    ports:
      - "5672:5672"
      - "15672:15672"
```

## Benefits of DAPR

✅ **Cloud-Agnostic**: Works on any cloud or on-premises
✅ **Language Agnostic**: Use any language or framework
✅ **Service Decoupling**: No direct service-to-service dependencies
✅ **Built-in Resilience**: Automatic retry, timeout, circuit breaker
✅ **State Abstraction**: Swap state stores without code changes
✅ **Event-Driven**: Pub/Sub abstracts message broker implementation
✅ **Security**: Built-in TLS, secrets management
✅ **Observability**: Distributed tracing, metrics collection
✅ **Standards-Based**: OpenTelemetry, gRPC, HTTP protocols
