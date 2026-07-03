# API Gateway - Low-Level Design

## Overview

The **API Gateway** is the single entry point for all client requests. It provides unified routing, authentication, rate limiting, request logging, and global error handling.

## Project Structure

### C# Project (.csproj)

```
Gateway/
├── BookRatings.Gateway/
│   ├── BookRatings.Gateway.csproj
│   ├── Program.cs
│   ├── Middleware/
│   │   ├── AuthenticationMiddleware.cs    # JWT token validation
│   │   ├── RequestLoggingMiddleware.cs    # Structured request logging
│   │   ├── ErrorHandlingMiddleware.cs     # Global error handling
│   │   ├── RateLimitingMiddleware.cs      # Per-user/IP rate limiting
│   │   ├── CorrelationIdMiddleware.cs     # Distributed tracing
│   │   └── RequestValidationMiddleware.cs
│   ├── Routes/
│   │   ├── BooksRoutes.cs                 # Route to Books Service
│   │   ├── RatingsRoutes.cs               # Route to Ratings Service
│   │   ├── UsersRoutes.cs                 # Route to Users Service
│   │   ├── AdminRoutes.cs                 # Route to Admin Service
│   │   ├── ReportingRoutes.cs             # Route to Reporting Service
│   │   └── HealthRoutes.cs                # Health check routes
│   ├── Policies/
│   │   ├── RateLimitPolicy.cs
│   │   ├── CircuitBreakerPolicy.cs
│   │   └── RetryPolicy.cs
│   ├── HttpClients/
│   │   ├── BooksServiceClient.cs
│   │   ├── RatingsServiceClient.cs
│   │   ├── UsersServiceClient.cs
│   │   ├── AdminServiceClient.cs
│   │   └── ReportingServiceClient.cs
│   ├── Models/
│   │   ├── GatewayRequest.cs
│   │   ├── GatewayResponse.cs
│   │   └── ErrorResponse.cs
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   └── appsettings.Production.json
│
└── BookRatings.Gateway.Tests/
    ├── BookRatings.Gateway.Tests.csproj
    ├── Unit/
    │   ├── Middleware/
    │   │   ├── AuthenticationMiddlewareTests.cs
    │   │   ├── RateLimitingMiddlewareTests.cs
    │   │   └── ErrorHandlingMiddlewareTests.cs
    │   └── Routes/
    │       └── RoutingTests.cs
    ├── Integration/
    │   ├── Fixtures/
    │   │   └── GatewayFixture.cs
    │   ├── Endpoints/
    │   │   ├── BooksRoutingTests.cs
    │   │   ├── RatingsRoutingTests.cs
    │   │   └── AuthenticationTests.cs
    │   └── docker-compose.yml
    └── E2E/
        └── GatewayE2ETests.cs
```

### .csproj Configuration

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <InvariantGlobalization>false</InvariantGlobalization>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="10.0.0" />
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="10.0.0" />
    <PackageReference Include="AspNetCoreRateLimit" Version="4.0.2" />
    <PackageReference Include="Polly" Version="8.2.0" />
    <PackageReference Include="Polly.Extensions.Http" Version="3.0.0" />
    <PackageReference Include="Serilog" Version="3.1.1" />
    <PackageReference Include="Serilog.AspNetCore" Version="8.0.1" />
    <PackageReference Include="Serilog.Sinks.Console" Version="5.0.1" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\Shared\BookRatings.Shared.Infrastructure\BookRatings.Shared.Infrastructure.csproj" />
  </ItemGroup>
</Project>
```

## Middleware Chain

```
Request
  ↓
CorrelationIdMiddleware          # Add correlation ID
  ↓
RequestLoggingMiddleware         # Log incoming request
  ↓
AuthenticationMiddleware         # Validate JWT
  ↓
RateLimitingMiddleware          # Check rate limits
  ↓
RequestValidationMiddleware     # Validate request
  ↓
ErrorHandlingMiddleware         # Handle errors globally
  ↓
Routing (to specific services)
  ↓
Response
```

## Middleware Implementations

### AuthenticationMiddleware

```csharp
public class AuthenticationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<AuthenticationMiddleware> _logger;

    public AuthenticationMiddleware(RequestDelegate next, ILogger<AuthenticationMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var token = context.Request.Headers["Authorization"].ToString()
            .Replace("Bearer ", "");

        if (string.IsNullOrEmpty(token))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new ErrorResponse
            {
                Error = "Unauthorized",
                Message = "Missing or invalid token"
            });
            return;
        }

        try
        {
            // Validate JWT token (implementation depends on Keycloak)
            var principal = ValidateToken(token);
            context.User = principal;

            _logger.LogInformation("User {UserId} authenticated", principal.FindFirst("sub")?.Value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Token validation failed");
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            await context.Response.WriteAsJsonAsync(new ErrorResponse
            {
                Error = "Unauthorized",
                Message = "Invalid token"
            });
            return;
        }

        await _next(context);
    }

    private ClaimsPrincipal ValidateToken(string token)
    {
        // JWT validation logic
        // This would typically use JwtSecurityTokenHandler
        throw new NotImplementedException();
    }
}
```

### RateLimitingMiddleware

```csharp
public class RateLimitingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IDistributedCache _cache;
    private readonly ILogger<RateLimitingMiddleware> _logger;

    public RateLimitingMiddleware(RequestDelegate next, IDistributedCache cache, 
        ILogger<RateLimitingMiddleware> logger)
    {
        _next = next;
        _cache = cache;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var userId = context.User?.FindFirst("sub")?.Value ?? context.Connection.RemoteIpAddress?.ToString();
        var key = $"rate_limit:{userId}";

        var requestCount = await GetRequestCountAsync(key);

        if (requestCount > 100) // 100 requests per minute
        {
            _logger.LogWarning("Rate limit exceeded for {UserId}", userId);
            context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
            await context.Response.WriteAsJsonAsync(new ErrorResponse
            {
                Error = "TooManyRequests",
                Message = "Rate limit exceeded. Please try again later."
            });
            return;
        }

        await IncrementRequestCountAsync(key);
        await _next(context);
    }

    private async Task<int> GetRequestCountAsync(string key)
    {
        var value = await _cache.GetStringAsync(key);
        return int.TryParse(value, out var count) ? count : 0;
    }

    private async Task IncrementRequestCountAsync(string key)
    {
        var count = await GetRequestCountAsync(key);
        await _cache.SetStringAsync(key, (count + 1).ToString(), 
            new DistributedCacheEntryOptions { AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(1) });
    }
}
```

### RequestLoggingMiddleware

```csharp
public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestLoggingMiddleware> _logger;

    public RequestLoggingMiddleware(RequestDelegate next, ILogger<RequestLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var correlationId = context.Items["CorrelationId"]?.ToString();
        var userId = context.User?.FindFirst("sub")?.Value;
        var method = context.Request.Method;
        var path = context.Request.Path;

        _logger.LogInformation(
            "Incoming request: {Method} {Path} from {RemoteIP} | CorrelationId: {CorrelationId} | UserId: {UserId}",
            method, path, context.Connection.RemoteIpAddress, correlationId, userId ?? "Anonymous");

        var stopwatch = Stopwatch.StartNew();
        await _next(context);
        stopwatch.Stop();

        _logger.LogInformation(
            "Response: {Method} {Path} | Status: {StatusCode} | Duration: {DurationMs}ms | CorrelationId: {CorrelationId}",
            method, path, context.Response.StatusCode, stopwatch.ElapsedMilliseconds, correlationId);
    }
}
```

### ErrorHandlingMiddleware

```csharp
public class ErrorHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ErrorHandlingMiddleware> _logger;

    public ErrorHandlingMiddleware(RequestDelegate next, ILogger<ErrorHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception");
            await HandleExceptionAsync(context, ex);
        }
    }

    private static Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        context.Response.ContentType = "application/json";

        var response = new ErrorResponse
        {
            Error = exception.GetType().Name,
            Message = exception.Message
        };

        context.Response.StatusCode = exception switch
        {
            ArgumentException => StatusCodes.Status400BadRequest,
            UnauthorizedAccessException => StatusCodes.Status401Unauthorized,
            _ => StatusCodes.Status500InternalServerError
        };

        return context.Response.WriteAsJsonAsync(response);
    }
}
```

## Service Routes

### BooksRoutes.cs

```csharp
public static class BooksRoutes
{
    public static void MapBooksRoutes(this WebApplication app, HttpClient booksClient)
    {
        var group = app.MapGroup("/api/books")
            .WithName("Books")
            .WithOpenApi()
            .WithTags("Books Service");

        group.MapGet("/", GetBooks);
        group.MapGet("/{id}", GetBookById);
        group.MapPost("/", CreateBook).RequireAuthorization();
        group.MapPut("/{id}", UpdateBook).RequireAuthorization();
        group.MapDelete("/{id}", DeleteBook).RequireAuthorization(p => p.RequireRole("Admin"));

        async Task<IResult> GetBooks(HttpContext context, [AsParameters] GetBooksRequest request)
        {
            var response = await booksClient.GetAsync(
                $"/api/books?skip={request.Skip}&take={request.Take}&sortBy={request.SortBy}");
            
            return response.IsSuccessStatusCode
                ? Results.Ok(await response.Content.ReadAsAsync<List<GetBooksResponse>>())
                : Results.StatusCode((int)response.StatusCode);
        }
    }
}
```

## Resilience Policies (Polly)

```csharp
// In Program.cs
builder.Services.AddHttpClient<BooksServiceClient>()
    .ConfigureHttpClient(client => client.BaseAddress = new Uri("http://localhost:5001"))
    .AddPolicyHandler(GetRetryPolicy())
    .AddPolicyHandler(GetCircuitBreakerPolicy());

// Retry policy: Retry 3 times with exponential backoff
private static IAsyncPolicy<HttpResponseMessage> GetRetryPolicy()
{
    return HttpPolicyExtensions
        .HandleTransientHttpError()
        .WaitAndRetryAsync(
            retryCount: 3,
            sleepDurationProvider: retryAttempt =>
                TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)),
            onRetry: (outcome, timespan, retryCount, context) =>
            {
                Console.WriteLine($"Retry {retryCount} after {timespan.TotalSeconds}s");
            });
}

// Circuit breaker: Open after 5 failures, half-open after 30s
private static IAsyncPolicy<HttpResponseMessage> GetCircuitBreakerPolicy()
{
    return HttpPolicyExtensions
        .HandleTransientHttpError()
        .CircuitBreakerAsync(
            handledEventsAllowedBeforeBreaking: 5,
            durationOfBreak: TimeSpan.FromSeconds(30),
            onBreak: (outcome, timespan) =>
            {
                Console.WriteLine($"Circuit breaker opened for {timespan.TotalSeconds}s");
            });
}
```

## Global Language Support

Gateway routes requests with language header to appropriate services:

```csharp
// Extract language from request
var language = context.Request.Headers["Accept-Language"].ToString() ?? "en-US";
context.Items["Language"] = language;

// Pass to downstream services
var headers = context.Request.Headers.ToDictionary(h => h.Key, h => h.Value.ToString());
headers["X-Language"] = language;
```

## API Endpoints

```csharp
var app = builder.Build();

// Health checks
app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready");

// Service routes
app.MapBooksRoutes(app.Services.GetRequiredService<HttpClient>());
app.MapRatingsRoutes(app.Services.GetRequiredService<HttpClient>());
app.MapUsersRoutes(app.Services.GetRequiredService<HttpClient>());
app.MapAdminRoutes(app.Services.GetRequiredService<HttpClient>());
app.MapReportingRoutes(app.Services.GetRequiredService<HttpClient>());

// OpenAPI/Swagger
app.UseOpenApi();
app.UseSwaggerUI();

app.Run();
```

## Configuration

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "ServiceEndpoints": {
    "BooksService": "http://localhost:5001",
    "RatingsService": "http://localhost:5002",
    "UsersService": "http://localhost:5003",
    "AdminService": "http://localhost:5004",
    "ReportingService": "http://localhost:5005"
  },
  "Keycloak": {
    "Authority": "https://keycloak.localhost/realms/bookratings",
    "Audience": "bookratings-api"
  },
  "RateLimit": {
    "RequestsPerMinute": 100,
    "RequestsPerHour": 1000
  },
  "AllowedHosts": "*",
  "Cors": {
    "AllowedOrigins": ["http://localhost:5012", "https://localhost:7247"],
    "AllowedMethods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    "AllowedHeaders": ["*"]
  }
}
```

## Build & Test Commands

```bash
# Build Gateway
dotnet build Gateway/

# Run tests
dotnet test Gateway/BookRatings.Gateway.Tests/ --filter "Category=Unit"

# Run integration tests with Podman
cd Gateway/BookRatings.Gateway.Tests/
docker-compose up -d
dotnet test --filter "Category=Integration"
docker-compose down

# Run Gateway locally
dotnet run --project Gateway/BookRatings.Gateway --launch-profile https
```
