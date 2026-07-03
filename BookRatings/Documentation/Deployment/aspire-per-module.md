# Aspire Per-Module Orchestration

## Overview

Each microservice module has its own Aspire orchestration host for local development, enabling independent service testing and multi-region deployment.

## Project Structure

```
Aspire/
├── BookRatings.Aspire.Global/          # Central Aspire for full system (optional)
│   ├── AppHost.cs
│   └── appsettings.json
│
├── BookRatings.Aspire.Books/           # Books Service Aspire
│   ├── AppHost.cs
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   ├── appsettings.Staging.json
│   └── appsettings.Production.json
│
├── BookRatings.Aspire.Ratings/         # Ratings Service Aspire
│   ├── AppHost.cs
│   └── appsettings.*.json
│
├── BookRatings.Aspire.Users/           # Users Service Aspire
│   ├── AppHost.cs
│   └── appsettings.*.json
│
├── BookRatings.Aspire.Admin/           # Admin Service Aspire
│   ├── AppHost.cs
│   └── appsettings.*.json
│
├── BookRatings.Aspire.Reporting/       # Reporting Service Aspire
│   ├── AppHost.cs
│   └── appsettings.*.json
│
└── BookRatings.Aspire.Gateway/         # API Gateway Aspire
    ├── AppHost.cs
    └── appsettings.*.json
```

## .csproj Configuration

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Aspire.Hosting" Version="10.0.0" />
    <PackageReference Include="Aspire.Hosting.Azure" Version="10.0.0" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\Services\Books\BookRatings.Services.Books\BookRatings.Services.Books.csproj" />
  </ItemGroup>
</Project>
```

## Module Aspire Host (AppHost.cs)

### Books Service Aspire Example

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Get environment
var environment = builder.Environment.EnvironmentName;
var config = builder.Configuration;

// Database (SQL Server)
var booksDb = builder
    .AddSqlServer("sqlserver", port: 1433)
    .WithEnvironment("SA_PASSWORD", config["SqlServer:Password"] ?? "YourPassword123!")
    .WithEnvironment("ACCEPT_EULA", "Y")
    .AddDatabase("books", databaseName: "BookRatings_Books");

// Message Queue (RabbitMQ)
var rabbitmq = builder
    .AddRabbitMQ("rabbitmq", port: 5672)
    .WithManagementUI();

// Cache (Redis) - Optional
var redis = builder
    .AddRedis("redis", port: 6379);

// Keycloak (for auth testing)
var keycloak = builder
    .AddKeycloak("keycloak", port: 8080)
    .WithEnvironment("KEYCLOAK_ADMIN", "admin")
    .WithEnvironment("KEYCLOAK_ADMIN_PASSWORD", config["Keycloak:AdminPassword"] ?? "admin");

// Books Service
var booksService = builder
    .AddProject<Projects.BookRatings_Services_Books>("books-service")
    .WithReference(booksDb)
    .WithReference(rabbitmq)
    .WithReference(redis)
    .WithReference(keycloak)
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", environment)
    .WithEnvironment("ConnectionStrings__DefaultConnection", booksDb.GetConnectionString("books"))
    .WithEnvironment("RabbitMQ__Host", rabbitmq.GetConnectionString())
    .WithEnvironment("Redis__ConnectionString", redis.GetConnectionString())
    .WithEnvironment("Keycloak__Authority", keycloak.GetConnectionString())
    .WithHttpEndpoint(port: 5001, isProxied: false)
    .WithOtlpExporter(); // OpenTelemetry

// Optional: Admin Service for Books moderation
var adminDb = builder
    .AddSqlServer("sqlserver")
    .AddDatabase("admin", databaseName: "BookRatings_Admin");

var adminService = builder
    .AddProject<Projects.BookRatings_Services_Admin>("admin-service")
    .WithReference(adminDb)
    .WithReference(rabbitmq)
    .WithReference(keycloak)
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", environment)
    .WithHttpEndpoint(port: 5004, isProxied: false);

// API Gateway (for Books APIs only)
var gateway = builder
    .AddProject<Projects.BookRatings_Gateway>("api-gateway")
    .WithReference(booksService)
    .WithReference(adminService)
    .WithReference(keycloak)
    .WithEnvironment("ServiceEndpoints__BooksService", booksService.GetEndpoint("http"))
    .WithHttpEndpoint(port: 5000, isProxied: false);

// OpenTelemetry Collector (optional)
builder.AddOtlpExporter("otlp");

await builder.Build().RunAsync();
```

## Environment-Specific Configuration

### appsettings.Development.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Information"
    }
  },
  "SqlServer": {
    "Password": "YourPassword123!"
  },
  "Keycloak": {
    "AdminPassword": "admin"
  },
  "Aspire": {
    "Dashboard": {
      "OtlpGrpcEndpoint": "http://localhost:4317",
      "OtlpHttpEndpoint": "http://localhost:4318"
    }
  }
}
```

### appsettings.Staging.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "${SQLSERVER_STAGING_CONNECTION_STRING}"
  },
  "Aspire": {
    "Dashboard": {
      "OtlpGrpcEndpoint": "${OTEL_STAGING_ENDPOINT}"
    }
  }
}
```

### appsettings.Production.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Error"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "${SQLSERVER_PRODUCTION_CONNECTION_STRING}"
  },
  "Aspire": {
    "Dashboard": {
      "OtlpGrpcEndpoint": "${OTEL_PRODUCTION_ENDPOINT}"
    }
  }
}
```

## Running Per-Module Aspire

```bash
# Run Books Service with its Aspire orchestration
cd Aspire/BookRatings.Aspire.Books
dotnet run

# Aspire Dashboard: http://localhost:18888

# Run Ratings Service independently
cd Aspire/BookRatings.Aspire.Ratings
dotnet run --configuration Staging

# Run with environment override
ASPNETCORE_ENVIRONMENT=Production dotnet run --project Aspire/BookRatings.Aspire.Books
```

## Multi-Region Per-Module Orchestration

```csharp
// AppHost.cs with region detection
var region = builder.Configuration["Deployment:Region"] ?? "us-east-1";
var environment = builder.Environment.EnvironmentName;

// Region-specific configuration
var sqlServerHost = region switch
{
    "eu-west-1" => "sqlserver.eu-west-1.local",
    "ap-southeast-1" => "sqlserver.ap-southeast-1.local",
    _ => "sqlserver.us-east-1.local"
};

var booksDb = builder
    .AddSqlServer("sqlserver", host: sqlServerHost, port: 1433);

// GDPR Compliance for EU
if (region == "eu-west-1")
{
    builder.AddResource(new EncryptionResource("database-encryption", "TLS-1.3"));
}
```

## Global Aspire Host (Optional)

For testing the full system, maintain a central Aspire host:

```csharp
// Aspire/BookRatings.Aspire.Global/AppHost.cs
var builder = DistributedApplication.CreateBuilder(args);

var environment = builder.Environment.EnvironmentName;

// Shared infrastructure
var sqlserver = builder.AddSqlServer("sqlserver", port: 1433);
var booksDb = sqlserver.AddDatabase("books");
var ratingsDb = sqlserver.AddDatabase("ratings");
var usersDb = sqlserver.AddDatabase("users");
var adminDb = sqlserver.AddDatabase("admin");
var reportingDb = sqlserver.AddDatabase("reporting");

var rabbitmq = builder.AddRabbitMQ("rabbitmq", port: 5672).WithManagementUI();
var redis = builder.AddRedis("redis", port: 6379);
var keycloak = builder.AddKeycloak("keycloak", port: 8080);

// All services
var books = builder.AddProject<Projects.BookRatings_Services_Books>("books-service")
    .WithReference(booksDb)
    .WithReference(rabbitmq)
    .WithReference(redis)
    .WithHttpEndpoint(port: 5001, isProxied: false)
    .WithOtlpExporter();

var ratings = builder.AddProject<Projects.BookRatings_Services_Ratings>("ratings-service")
    .WithReference(ratingsDb)
    .WithReference(rabbitmq)
    .WithReference(redis)
    .WithHttpEndpoint(port: 5002, isProxied: false)
    .WithOtlpExporter();

// ... (other services)

// API Gateway routes to all services
var gateway = builder.AddProject<Projects.BookRatings_Gateway>("api-gateway")
    .WithReference(books)
    .WithReference(ratings)
    // ... other service references
    .WithHttpEndpoint(port: 5000, isProxied: false);

// Web Client
var web = builder.AddProject<Projects.BookRatings_Web>("web-client")
    .WithReference(gateway)
    .WithHttpEndpoint(port: 5012, isProxied: false);

await builder.Build().RunAsync();
```

## Aspire Dashboard

Each Aspire host provides a dashboard at `http://localhost:18888`:
- **Resources**: View all running services, databases, message queues
- **Logs**: Real-time logs from all services
- **Traces**: Distributed tracing across services
- **Metrics**: Performance metrics (CPU, memory, HTTP requests)
- **Health**: Service health status

## Integration with DAPR (Optional)

```csharp
// For DAPR sidecar injection in Aspire
var booksService = builder
    .AddProject<Projects.BookRatings_Services_Books>("books-service")
    .WithReference(booksDb)
    .WithReference(rabbitmq)
    .WithEnvironment("DAPR_HTTP_PORT", "3500")
    .WithEnvironment("DAPR_GRPC_PORT", "50001")
    .WithHttpEndpoint(port: 5001, isProxied: false)
    .WithOtlpExporter();
```

## Benefits of Per-Module Aspire

✅ **Independent Development**: Develop and test one service without running entire system
✅ **Multi-Region Ready**: Region-specific configuration per module
✅ **Reduced Resource Usage**: Only run what you need for development
✅ **Service Isolation**: Test service in isolation before integration
✅ **Scalable Testing**: Run multiple instances of same service for load testing
✅ **Environment Parity**: Same configuration for dev/staging/production
