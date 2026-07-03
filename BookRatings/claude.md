# Claude Agent Instructions for BookRatings

You are an AI coding assistant helping developers build the **BookRatings** application, an **enterprise-grade, multi-device book rating and review platform** using Clean Architecture, Vertical Slice Architecture, and Microservices patterns.

## Quick Reference

### Build & Run
```bash
# Build all projects
dotnet build

# Run with Aspire (Aspire host orchestrates all services)
dotnet run --project BookRatings.Aspire

# Run individual service with HTTPS
dotnet run --project BookRatings.Services.Books --launch-profile https

# Run individual service with HTTP
dotnet run --project BookRatings.Services.Books --launch-profile http

# Run tests with Podman containers
dotnet test --environment=docker

# Build Podman container images
podman build -t bookratings/books-service:latest -f Services/Books/Dockerfile .
```

**Development URLs**: 
- Aspire Dashboard: `http://localhost:18888`
- API Gateway: `http://localhost:5000`
- Books Service: `http://localhost:5001`
- Ratings Service: `http://localhost:5002`
- Users Service: `http://localhost:5003`
- Admin Service: `http://localhost:5004`

## Project Overview

**BookRatings** is an **enterprise-grade, cloud-native microservices platform** (.NET 10.0) designed for rating and reviewing books across all device types (mobile, desktop, tablet) with offline support, global regional availability, and comprehensive observability.

**Comprehensive Documentation**:
- [High-Level Design (HLD)](Documentation/HLD/architecture.md) - Overall system design and interactions
- **Low-Level Design (LLD) - Module Specifications**:
  - [Books Service](Documentation/LLD/books-service.md) - Book catalog management, .csproj, .sqlproj, DACPAC, Podman tests, i18n
  - [Ratings Service](Documentation/LLD/ratings-service.md) - Rating aggregation, event consumption, analytics
  - [Users Service](Documentation/LLD/users-service.md) - User management, Keycloak integration, profiles
  - [Admin Service](Documentation/LLD/admin-service.md) - Moderation, audit logs, system config
  - [Reporting Service](Documentation/LLD/reporting-service.md) - Analytics, trends, export (CSV/Excel/PDF)
  - [API Gateway](Documentation/LLD/api-gateway.md) - Routing, auth, rate limiting, error handling

**Architecture Approach**:
- **Clean Architecture**: Separation of concerns with Domain, Application, Infrastructure, and Presentation layers
- **Vertical Slice Architecture**: Each module is self-contained with its own vertical slice (request to database)
- **TOFAG Enterprise Architecture**: Transactional, Operational, Financial, Analytics, and Governance layers
- **Microservices**: Module-per-service pattern with API Gateway for client-facing requests
- **Cloud-Agnostic Deployment**: Podman containers, Kubernetes-ready manifests

**Tech Stack**:
- **Framework**: ASP.NET Core 10.0 with Minimal APIs
- **Messaging**: MassTransit for service-to-service communication
- **Data Access**: Entity Framework Core with SQLite (offline), SQL Server (online)
- **API Pattern**: REST with OpenAPI/Swagger, HATEOAS support
- **Authentication & Authorization**: Keycloak (OpenID Connect), WASP security framework
- **Observability**: OpenTelemetry, Prometheus metrics, Grafana dashboards, DataDog integration, Application Insights
- **Health Monitoring**: Watchdog service for distributed health checks
- **Aspire**: .NET Aspire 10 for service orchestration and configuration
- **Containers**: Podman for testing and deployment
- **Styling**: Bootstrap 5 (UI), TailwindCSS (responsive design)
- **State Management**: Server-side (Blazor Server) + distributed cache (Redis)

**Key Features**:
- Nullable reference types enabled
- Vertical slice organization per feature
- Offline-first with SQLite synchronization
- Multi-region deployment support
- Comprehensive REST API design (CRUD, filtering, pagination, sorting)
- Real-time updates via WebSocket (SignalR)
- Distributed tracing across services
- Centralized logging with structured logs
- Health checks and readiness probes
- Circuit breaker and retry policies
- WASP security compliance (authentication, authorization, data protection)

## Project Structure

### Build Configuration Files

Each service includes:

#### C# Project Files (.csproj)

Every service has its own `.csproj` configuration:

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <InvariantGlobalization>false</InvariantGlobalization>
  </PropertyGroup>

  <ItemGroup>
    <!-- EF Core, MassTransit, Authentication -->
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="10.0.0" />
    <PackageReference Include="MassTransit" Version="8.1.0" />
    <PackageReference Include="FluentValidation" Version="11.8.0" />
  </ItemGroup>
</Project>
```

**Key Settings**:
- `TargetFramework`: net10.0 for all services
- `Nullable`: enable for type safety
- `InvariantGlobalization`: false to support all languages/locales

#### SQL Server Project Files (.sqlproj)

Each service has a database project for DACPAC generation:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <PropertyGroup>
    <Name>BookRatings.Services.Books.Database</Name>
    <DSP>Microsoft.Data.Tools.Schema.Sql.Sql150DatabaseSchemaProvider</DSP>
    <GenerateCreateScript>True</GenerateCreateScript>
  </PropertyGroup>
  
  <ItemGroup>
    <Build Include="dbo\Tables\Books.sql" />
    <Build Include="dbo\Views\vw_BookStats.sql" />
    <Build Include="dbo\StoredProcedures\sp_GetBooks.sql" />
  </ItemGroup>
</Project>
```

**DACPAC Workflow**:

```bash
# Build DACPAC package
msbuild Services/Books/BookRatings.Services.Books.Database.sqlproj /t:Build /p:Configuration=Release

# Deploy to SQL Server
sqlpackage /Action:Publish \
  /SourceFile:bin\Release\BookRatings.Services.Books.Database.dacpac \
  /TargetServerName:localhost \
  /TargetDatabaseName:BookRatings_Books \
  /p:VerifyDeployment=True
```

#### Integration Testing with Podman

Each service includes `docker-compose.yml` for containerized testing:

```yaml
version: '3.8'

services:
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      SA_PASSWORD: "YourPassword123!"
      ACCEPT_EULA: "Y"
    ports:
      - "1433:1433"
    healthcheck:
      test: ["CMD", "/opt/mssql-tools/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", "YourPassword123!", "-Q", "SELECT 1"]
      interval: 10s
      timeout: 3s
      retries: 5

  rabbitmq:
    image: rabbitmq:3.12-management
    ports:
      - "5672:5672"
      - "15672:15672"
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

**Run Integration Tests**:

```bash
cd Services/Books/BookRatings.Services.Books.Tests/
docker-compose up -d
dotnet test --filter "Category=Integration"
docker-compose down
```

#### Globalization & Multi-Language Support

All services support global languages:

**Supported Languages**:
- English (en-US) - Default
- French (fr-FR)
- German (de-DE)
- Spanish (es-ES)
- Japanese (ja-JP)
- Simplified Chinese (zh-CN)
- Portuguese (pt-BR)

**Implementation**:

```csharp
// In Program.cs - Configure localization
var supportedCultures = new[] 
{ 
    new CultureInfo("en-US"),
    new CultureInfo("fr-FR"),
    new CultureInfo("de-DE"),
    // ... more cultures
};

builder.Services.AddLocalization(options =>
{
    options.ResourcesPath = "Resources";
});

builder.Services.AddRequestLocalization(options =>
{
    options.DefaultRequestCulture = new RequestCulture("en-US");
    options.SupportedCultures = supportedCultures;
    options.SupportedUICultures = supportedCultures;
});
```

**Resource Files** - One per language:

```
Services/Books/Resources/
├── Messages.resx                    # English (default)
├── Messages.fr-FR.resx              # French
├── Messages.de-DE.resx              # German
├── Messages.es-ES.resx              # Spanish
├── Messages.ja-JP.resx              # Japanese
├── Messages.zh-CN.resx              # Chinese
└── Messages.pt-BR.resx              # Portuguese
```

**Usage in Validation & Responses**:

```csharp
public class CreateBookValidator : AbstractValidator<CreateBookRequest>
{
    private readonly IStringLocalizer<CreateBookValidator> _localizer;

    public CreateBookValidator(IStringLocalizer<CreateBookValidator> localizer)
    {
        _localizer = localizer;

        RuleFor(x => x.Title)
            .NotEmpty()
            .WithMessage(_localizer["Title_Required"]);
    }
}
```

### Microservices Architecture

```
BookRatings/
├── BookRatings.Aspire/                    # .NET Aspire orchestration host
│   ├── AppHost.cs                         # Service definitions and composition
│   ├── appsettings.json                   # Aspire configuration
│   └── Properties/launchSettings.json
│
├── Services/
│   ├── Books/                             # Books Management Service (Vertical Slice)
│   │   ├── BookRatings.Services.Books/
│   │   │   ├── Core/
│   │   │   │   └── Domain/
│   │   │   │       ├── Book.cs            # Book aggregate root
│   │   │   │       └── BookException.cs
│   │   │   ├── Features/
│   │   │   │   ├── GetBooks/              # Vertical slice: List books
│   │   │   │   │   ├── Handler.cs
│   │   │   │   │   ├── Request.cs
│   │   │   │   │   └── Response.cs
│   │   │   │   ├── GetBookById/           # Vertical slice: Get book details
│   │   │   │   ├── CreateBook/            # Vertical slice: Add new book
│   │   │   │   ├── UpdateBook/            # Vertical slice: Update book
│   │   │   │   └── DeleteBook/            # Vertical slice: Remove book
│   │   │   ├── Data/
│   │   │   │   ├── BooksContext.cs        # EF Core DbContext
│   │   │   │   └── Migrations/
│   │   │   ├── Services/
│   │   │   │   └── BookService.cs
│   │   │   ├── Endpoints/                 # Minimal API endpoints
│   │   │   │   └── BookEndpoints.cs
│   │   │   ├── Program.cs
│   │   │   └── appsettings.json
│   │   ├── BookRatings.Services.Books.Tests/
│   │   └── Dockerfile                      # Podman/Docker image
│   │
│   ├── Ratings/                           # Ratings Management Service
│   │   ├── BookRatings.Services.Ratings/
│   │   │   ├── Core/Domain/
│   │   │   │   ├── Rating.cs              # Rating aggregate root
│   │   │   │   └── RatingException.cs
│   │   │   ├── Features/
│   │   │   │   ├── SubmitRating/          # Vertical slice
│   │   │   │   ├── GetRatings/            # Vertical slice
│   │   │   │   ├── UpdateRating/
│   │   │   │   └── DeleteRating/
│   │   │   ├── Data/
│   │   │   │   ├── RatingsContext.cs
│   │   │   │   └── Migrations/
│   │   │   ├── Endpoints/
│   │   │   ├── Program.cs
│   │   │   └── appsettings.json
│   │   └── BookRatings.Services.Ratings.Tests/
│   │
│   ├── Users/                             # User Management Service
│   │   ├── BookRatings.Services.Users/
│   │   │   ├── Core/Domain/
│   │   │   │   └── User.cs
│   │   │   ├── Features/
│   │   │   │   ├── GetUser/
│   │   │   │   ├── CreateUser/
│   │   │   │   ├── UpdateProfile/
│   │   │   │   └── DeleteUser/
│   │   │   ├── Data/
│   │   │   │   ├── UsersContext.cs
│   │   │   │   └── Migrations/
│   │   │   ├── Endpoints/
│   │   │   ├── Program.cs
│   │   │   └── appsettings.json
│   │   └── BookRatings.Services.Users.Tests/
│   │
│   ├── Admin/                             # Admin Management Service
│   │   ├── BookRatings.Services.Admin/
│   │   │   ├── Features/
│   │   │   │   ├── UserManagement/        # Admin user management
│   │   │   │   ├── ContentModeration/     # Moderate reviews
│   │   │   │   └── SystemConfiguration/   # Admin settings
│   │   │   ├── Data/
│   │   │   ├── Endpoints/
│   │   │   ├── Program.cs
│   │   │   └── appsettings.json
│   │   └── BookRatings.Services.Admin.Tests/
│   │
│   └── Reporting/                         # Reporting & Analytics Service
│       ├── BookRatings.Services.Reporting/
│       │   ├── Features/
│       │   │   ├── BookAnalytics/         # Book ratings analytics
│       │   │   ├── UserAnalytics/         # User activity reports
│       │   │   ├── RatingTrends/          # Rating trends over time
│       │   │   └── ExportReports/         # Export to CSV, Excel, PDF
│       │   ├── Data/
│       │   ├── Endpoints/
│       │   ├── Program.cs
│       │   └── appsettings.json
│       └── BookRatings.Services.Reporting.Tests/
│
├── Gateway/                               # API Gateway
│   ├── BookRatings.Gateway/
│   │   ├── Middleware/
│   │   │   ├── AuthenticationMiddleware.cs
│   │   │   ├── RequestLoggingMiddleware.cs
│   │   │   └── ErrorHandlingMiddleware.cs
│   │   ├── Routes/
│   │   │   ├── BooksRoutes.cs
│   │   │   ├── RatingsRoutes.cs
│   │   │   ├── UsersRoutes.cs
│   │   │   └── AdminRoutes.cs
│   │   ├── Program.cs
│   │   └── appsettings.json
│   └── BookRatings.Gateway.Tests/
│
├── Clients/
│   ├── Web/                               # Blazor Server Web UI
│   │   ├── BookRatings.Web/
│   │   │   ├── Components/
│   │   │   │   ├── App.razor
│   │   │   │   ├── Routes.razor
│   │   │   │   ├── _Imports.razor
│   │   │   │   ├── Layout/
│   │   │   │   │   ├── MainLayout.razor
│   │   │   │   │   ├── NavMenu.razor
│   │   │   │   │   └── ReconnectModal.razor
│   │   │   │   └── Pages/
│   │   │   │       ├── Home.razor
│   │   │   │       ├── Books/
│   │   │   │       │   ├── BookList.razor
│   │   │   │       │   └── BookDetail.razor
│   │   │   │       ├── Ratings/
│   │   │   │       │   └── SubmitRating.razor
│   │   │   │       ├── Admin/
│   │   │   │       └── Dashboard/
│   │   │   ├── Services/
│   │   │   │   ├── BooksClient.cs         # HTTP client for Books Service
│   │   │   │   ├── RatingsClient.cs
│   │   │   │   ├── UsersClient.cs
│   │   │   │   └── AuthService.cs         # Keycloak integration
│   │   │   ├── wwwroot/
│   │   │   │   ├── app.css
│   │   │   │   └── lib/
│   │   │   ├── Program.cs
│   │   │   └── appsettings.json
│   │   └── BookRatings.Web.Tests/
│   │
│   └── Mobile/                            # Mobile Apps (.NET MAUI)
│       ├── BookRatings.Mobile/
│       │   ├── Views/
│       │   │   ├── BookListPage.xaml
│       │   │   ├── RatingPage.xaml
│       │   │   └── ProfilePage.xaml
│       │   ├── ViewModels/
│       │   │   ├── BookListViewModel.cs
│       │   │   └── RatingViewModel.cs
│       │   ├── Services/
│       │   │   ├── OfflineSyncService.cs  # SQLite sync to cloud
│       │   │   └── ApiClient.cs
│       │   ├── Data/
│       │   │   └── OfflineDatabase.cs     # SQLite local database
│       │   ├── MauiProgram.cs
│       │   └── appsettings.json
│       └── BookRatings.Mobile.Tests/
│
├── Shared/                                # Shared libraries
│   ├── BookRatings.Shared.Domain/         # Domain models & contracts
│   │   ├── Books/
│   │   │   └── BookDto.cs
│   │   ├── Ratings/
│   │   │   └── RatingDto.cs
│   │   ├── Users/
│   │   │   └── UserDto.cs
│   │   └── Exceptions/
│   │
│   ├── BookRatings.Shared.Contracts/      # Service contracts & events
│   │   ├── Events/
│   │   │   ├── BookCreatedEvent.cs
│   │   │   ├── RatingSubmittedEvent.cs
│   │   │   └── UserRegisteredEvent.cs
│   │   └── Requests/
│   │
│   ├── BookRatings.Shared.Infrastructure/ # Shared infrastructure
│   │   ├── Persistence/
│   │   │   ├── UnitOfWork.cs
│   │   │   └── Repository.cs
│   │   ├── Observability/
│   │   │   ├── TelemetryService.cs
│   │   │   └── HealthChecks.cs
│   │   ├── Security/
│   │   │   ├── WaspSecurityPolicy.cs
│   │   │   └── AuthenticationHandler.cs
│   │   └── Cache/
│   │       └── DistributedCacheService.cs
│   │
│   └── BookRatings.Shared.Testing/        # Shared test utilities
│       ├── Fixtures/
│       ├── TestData/
│       └── MockServices/
│
├── Deployment/                            # Infrastructure & deployment
│   ├── kubernetes/                        # K8s manifests for cloud-native deployment
│   │   ├── books-service.yaml
│   │   ├── ratings-service.yaml
│   │   ├── api-gateway.yaml
│   │   └── configmap.yaml
│   ├── podman/                            # Podman Compose for local development
│   │   ├── docker-compose.yml
│   │   └── .env
│   ├── helm/                              # Helm charts for deployment
│   │   └── bookratings/
│   └── terraform/                         # Infrastructure-as-Code
│       ├── main.tf
│       └── variables.tf
│
├── Documentation/                         # Comprehensive documentation
│   ├── HLD/                               # High-Level Design diagrams
│   │   ├── architecture.md                # Overall system architecture
│   │   ├── service-interactions.md        # How services communicate
│   │   └── data-flow.md                   # Data flow across system
│   ├── LLD/                               # Low-Level Design for each module
│   │   ├── books-service.md               # Books service detailed design
│   │   ├── ratings-service.md
│   │   ├── users-service.md
│   │   ├── admin-service.md
│   │   ├── reporting-service.md
│   │   └── api-gateway.md
│   ├── API/                               # REST API documentation
│   │   ├── books-api.md                   # Books endpoints & schemas
│   │   ├── ratings-api.md
│   │   ├── users-api.md
│   │   ├── admin-api.md
│   │   └── reporting-api.md
│   ├── SECURITY.md                        # Security & WASP compliance
│   ├── DEPLOYMENT.md                      # Deployment & cloud-agnostic guide
│   ├── OFFLINE_SUPPORT.md                 # Offline-first strategy
│   ├── OBSERVABILITY.md                   # Telemetry, logging, monitoring
│   └── DEVELOPMENT.md                     # Contributing & development guide
│
├── Tests/                                 # Integration & E2E tests
│   ├── BookRatings.Integration.Tests/
│   └── BookRatings.E2E.Tests/
│
├── BookRatings.sln                        # Solution file
├── Directory.Build.props                  # Shared build configuration
└── .editorconfig                          # Code style standards
```

### Vertical Slice Organization

Each feature (GetBooks, CreateBook, etc.) is self-contained within its vertical slice:

```
Features/GetBooks/
├── Request.cs          # Input contract
├── Response.cs         # Output contract
├── Handler.cs          # Business logic (use case)
├── Validator.cs        # Input validation (FluentValidation)
├── Mapper.cs           # DTO mapping
└── GetBooksEndpoint.cs # HTTP endpoint
```

## Architecture & Patterns

### Clean Architecture Layers

Each service follows Clean Architecture with four distinct layers:

1. **Domain Layer** (`Core/Domain/`)
   - Entity aggregates (Book, Rating, User)
   - Domain exceptions
   - No external dependencies

2. **Application Layer** (`Features/`, `Services/`)
   - Use case handlers (business logic)
   - Input validation
   - DTO mapping
   - No direct database access

3. **Infrastructure Layer** (`Data/`, shared infrastructure)
   - Entity Framework Core DbContext
   - Database migrations
   - External service integrations (Keycloak, message queue)
   - Observability implementations

4. **Presentation Layer** (`Endpoints/`, Web/Mobile Clients)
   - Minimal API endpoints
   - HTTP request/response handling
   - Request routing

### Vertical Slice Architecture

- **One feature = One vertical slice** (request → database → response)
- Each slice has Request, Response, Handler, Validator, and Endpoint
- Slices are organized by feature (GetBooks, CreateBook, etc.)
- Minimal coupling between slices
- Easy to modify one feature without affecting others

### TOFAG Enterprise Architecture

Layers organizing cross-cutting concerns:

1. **Transactional (T)**: Data consistency, transactions, repositories
2. **Operational (O)**: Health checks, logging, monitoring, alerting
3. **Financial (F)**: Usage tracking, billing, cost attribution
4. **Analytics (A)**: Reporting service, trends, insights, dashboards
5. **Governance (G)**: Security, compliance, audit logs, WASP framework

### Microservices Pattern

- **One service per bounded context** (Books, Ratings, Users, Admin, Reporting)
- **Independent deployment** - each service has its own CI/CD pipeline
- **Database per service** - isolated SQLite (offline) and SQL Server (online)
- **Service-to-service communication** via **Event-Driven Architecture** (MassTransit async messaging)
- **Event-Driven Communication**: Services publish domain events, other services subscribe and react
- **API Gateway** for client-facing unified interface
- **Loose Coupling**: Services don't know about each other, only about events

### Multi-Device Support

- **Web**: Blazor Server (Windows, macOS, Linux, all browsers)
- **Mobile**: .NET MAUI (iOS, Android)
- **Desktop**: WPF or Blazor Desktop

### Offline-First Architecture

```
┌─────────────────────────────────────────────────┐
│ Client Application (Web/Mobile)                 │
│  ┌──────────────────────────────────────────┐   │
│  │ SQLite Local Database                    │   │
│  │ (Books, Ratings, User cache)             │   │
│  └──────────────────────────────────────────┘   │
│              ↓ (Auto-sync)                      │
│  ┌──────────────────────────────────────────┐   │
│  │ SyncService (on network available)       │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
         ↓ HTTPS ↓ (when connected)
┌─────────────────────────────────────────────────┐
│ API Gateway (http://localhost:5000)             │
│  ├── Books Service (5001)                       │
│  ├── Ratings Service (5002)                     │
│  ├── Users Service (5003)                       │
│  ├── Admin Service (5004)                       │
│  └── Reporting Service (5005)                   │
│              ↓                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ SQL Server (cloud database)              │   │
│  │ - Synchronized from SQLite clients       │   │
│  │ - Master data source                     │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Data Synchronization Strategy

- **Client offline**: Queued mutations stored in SQLite
- **Network available**: Automatic sync via SyncService
- **Conflict resolution**: Last-write-wins or custom business logic
- **Event sourcing**: Mutation events tracked for audit

### Event-Driven Architecture (Service Communication)

Services communicate asynchronously through domain events rather than synchronous HTTP calls:

```
Book Service publishes BookCreatedEvent
    ↓
MassTransit (RabbitMQ/MSMQ)
    ↓
Ratings Service subscribes → updates derived data
Admin Service subscribes → logs event for auditing
Reporting Service subscribes → updates analytics
Search Service subscribes → indexes new book
```

**Event Publishing**:
```csharp
// In Books Service - Feature Handler
public class CreateBookHandler : IRequestHandler<CreateBookRequest, CreateBookResponse>
{
    private readonly IPublishEndpoint _publishEndpoint;
    
    public async Task<CreateBookResponse> Handle(CreateBookRequest request, CancellationToken ct)
    {
        var book = new Book { Title = request.Title, Author = request.Author };
        await _repository.AddAsync(book);
        
        // Publish event for other services to subscribe
        await _publishEndpoint.Publish(new BookCreatedEvent
        {
            BookId = book.Id,
            Title = book.Title,
            Author = book.Author,
            CreatedAt = DateTime.UtcNow
        }, ct);
        
        return new CreateBookResponse { Id = book.Id };
    }
}
```

**Event Subscription**:
```csharp
// In Ratings Service - Event Consumer
public class BookCreatedEventConsumer : IConsumer<BookCreatedEvent>
{
    private readonly IRepository<BookCache> _cacheRepository;
    
    public async Task Consume(ConsumeContext<BookCreatedEvent> context)
    {
        var bookEvent = context.Message;
        
        // Cache book data for ratings lookups
        await _cacheRepository.AddAsync(new BookCache
        {
            BookId = bookEvent.BookId,
            Title = bookEvent.Title,
            Author = bookEvent.Author
        });
        
        await Task.CompletedTask;
    }
}
```

**MassTransit Configuration**:
```csharp
// In Program.cs - each service
builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<BookCreatedEventConsumer>();
    x.AddConsumer<RatingSubmittedEventConsumer>();
    
    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host("rabbitmq://localhost");
        cfg.ConfigureEndpoints(context);
    });
});
```

**Event Types**:
- `BookCreatedEvent` - Published by Books Service when new book added
- `BookUpdatedEvent` - Published by Books Service when book modified
- `BookDeletedEvent` - Published by Books Service when book removed
- `RatingSubmittedEvent` - Published by Ratings Service when rating added
- `RatingUpdatedEvent` - Published by Ratings Service when rating changed
- `UserRegisteredEvent` - Published by Users Service when user joins
- `ReviewModerationEvent` - Published by Admin Service for content reviews

**Benefits of Event-Driven**:
- **Loose Coupling**: Services don't call each other directly
- **Scalability**: Multiple subscribers can react to same event
- **Resilience**: If subscriber is down, events queue and process later
- **Audit Trail**: All events are logged for compliance
- **Eventually Consistent**: Data synchronizes across services via events

### Multi-Region Deployment

- **Aspire hosts** per region (US East, EU West, APAC, etc.)
- **Keycloak** as centralized identity provider
- **Data replication** across regions for GDPR compliance
- **Geo-routing** via API Gateway based on client location

## Development Conventions

### Minimal APIs Design

All services use Minimal APIs (no MVC controllers):

```csharp
// Program.cs
var builder = WebApplicationBuilder.CreateBuilder(args);
builder.Services.AddScoped<IBookService, BookService>();
var app = builder.Build();

var group = app.MapGroup("/api/books")
    .WithName("Books")
    .WithOpenApi()
    .RequireAuthorization();

group.MapGet("/", GetBooks).WithName("GetBooks").Produces<List<BookDto>>();
group.MapGet("/{id}", GetBookById).WithName("GetBookById").Produces<BookDto>();
group.MapPost("/", CreateBook).WithName("CreateBook").Accepts<CreateBookRequest>();
group.MapPut("/{id}", UpdateBook).WithName("UpdateBook");
group.MapDelete("/{id}", DeleteBook).WithName("DeleteBook");

app.Run();
```

### REST API Design Features

Each endpoint includes:

1. **CRUD Operations**
   - GET (list, single) - 200 OK
   - POST (create) - 201 Created
   - PUT (update) - 204 No Content
   - DELETE - 204 No Content
   - PATCH (partial) - 200 OK

2. **Filtering & Pagination**
   ```
   GET /api/books?skip=0&take=10&sortBy=title&sortOrder=asc
   GET /api/ratings?bookId=123&minScore=4&maxScore=5
   ```

3. **HAT EOAS (Hypermedia As The Engine Of Application State)**
   ```json
   {
     "id": 1,
     "title": "Book Title",
     "_links": {
       "self": { "href": "/api/books/1" },
       "all": { "href": "/api/books" },
       "ratings": { "href": "/api/books/1/ratings" }
     }
   }
   ```

4. **Error Responses (RFC 7807 - Problem Details)**
   ```json
   {
     "type": "https://api.bookratings.com/errors/validation-failed",
     "title": "Validation Failed",
     "status": 400,
     "detail": "The request body contains invalid data",
     "instance": "/api/books",
     "errors": {
       "title": ["Title is required"]
     }
   }
   ```

5. **Content Negotiation**
   - JSON (default)
   - XML (via accept header)
   - CSV (for reports)

6. **Caching Headers**
   ```
   Cache-Control: max-age=3600, public
   ETag: "version-hash"
   Last-Modified: timestamp
   ```

### File Organization

- **Features/FeatureName/** - Feature vertical slice
  - `Request.cs` - Input contract
  - `Response.cs` - Output contract
  - `Handler.cs` - Business logic
  - `Validator.cs` - Fluent validation
  - `Mapper.cs` - AutoMapper profile
  - `Endpoint.cs` - Minimal API endpoint
- **Core/Domain/** - Domain entities
- **Data/** - EF Core DbContext & migrations
- **Services/** - Business logic services
- **Endpoints/** - Minimal API route groups

### Naming Conventions

- **Namespaces**: `BookRatings.Services.Books.Features.GetBooks`
- **Classes**: PascalCase (`GetBooksHandler`, `CreateBookValidator`)
- **Methods**: PascalCase (`GetBook()`, `CreateRating()`)
- **Properties**: PascalCase (`BookId`, `RatingScore`)
- **Variables**: camelCase (`bookId`, `ratingList`)
- **Constants**: UPPER_CASE (`MAX_RATING = 5`)
- **Database tables**: Plural (`Books`, `Ratings`)
- **Endpoints**: Kebab-case routes (`/api/books`, `/api/ratings`)

### Code Organization in Features

```csharp
// Handler.cs - Business logic
public class GetBooksHandler
{
    private readonly IBookService _bookService;
    
    public GetBooksHandler(IBookService bookService)
    {
        _bookService = bookService;
    }
    
    public async Task<List<BookResponse>> Handle(GetBooksRequest request)
    {
        var books = await _bookService.GetBooksAsync(request.Skip, request.Take);
        return books.Select(MapToResponse).ToList();
    }
}

// Endpoint.cs - HTTP binding
public static class BookEndpoints
{
    public static void MapBookEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/books");
        group.MapGet("/", GetBooks).WithName("GetBooks");
    }
    
    private static async Task<IResult> GetBooks(IMediator mediator, GetBooksRequest request)
    {
        var response = await mediator.Send(request);
        return Results.Ok(response);
    }
}
```

## Security & WASP Compliance

### Authentication (Keycloak)

- **Provider**: Keycloak OpenID Connect
- **Configuration**:
  ```json
  {
    "Keycloak": {
      "Authority": "https://keycloak.bookratings.com/realms/bookratings",
      "ClientId": "bookratings-api",
      "ClientSecret": "secret",
      "ResponseType": "code"
    }
  }
  ```
- **User Roles**: Admin, Moderator, Reader, Reviewer
- **Token**: JWT with roles and claims

### Authorization (WASP Framework)

Security layer ensures:

1. **Authentication**: All API endpoints require valid JWT token
2. **Authorization**: Role-based access control (RBAC)
3. **Data Protection**: Encryption at rest and in transit (TLS 1.3)
4. **Audit Logging**: All sensitive operations logged
5. **Input Validation**: All user inputs validated (FluentValidation)
6. **CORS**: Restricted to approved origins
7. **Rate Limiting**: Per-user and per-IP rate limiting
8. **SQL Injection Prevention**: Parameterized queries (EF Core)

### Implementation

```csharp
// Endpoint with authorization
var group = app.MapGroup("/api/admin")
    .RequireAuthorization()
    .WithTags("Admin")
    .AddOpenApiSecurityRequirement();

group.MapDelete("/users/{id}", DeleteUser)
    .RequireAuthorization(policy => policy.RequireRole("Admin"))
    .WithName("DeleteUser");
```

## Observability & Monitoring

### OpenTelemetry Integration

Distributed tracing across all services:

```csharp
builder.Services
    .AddOpenTelemetry()
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddEntityFrameworkCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter(opt => opt.Endpoint = new Uri("http://localhost:4317")))
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddProcessInstrumentation()
        .AddOtlpExporter());
```

### Metrics (Prometheus)

- Request count, latency, errors
- Database query performance
- Service health and uptime
- Custom business metrics (ratings submitted, books added)

**Prometheus endpoint**: `http://service:port/metrics`

### Logging (Structured Logs)

```csharp
builder.Services.AddLogging(logging =>
{
    logging.AddConsole();
    logging.AddApplicationInsights();
});

// Structured logging
_logger.LogInformation("Book {BookId} rated with score {Score}", bookId, score);
```

### Health Checks (Watchdog Service)

Each service exposes:
- `/health/live` - Liveness probe (pod alive?)
- `/health/ready` - Readiness probe (ready to receive traffic?)
- `/health/detailed` - Detailed health including dependencies

```csharp
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("live")
});
```

### Grafana Dashboards

Visual representation of:
- Service metrics across regions
- Request latency percentiles (p50, p95, p99)
- Error rates and types
- Database performance
- User activity trends

### DataDog Integration

Advanced monitoring and alerting:
- APM for distributed tracing
- Custom metric collection
- Real user monitoring
- Service dependency mapping

## Data Access Pattern

### Entity Framework Core

### SQLite (Offline - Client)

```csharp
// OfflineDatabase.cs in Mobile/Web client
public class OfflineDbContext : DbContext
{
    public DbSet<Book> Books { get; set; }
    public DbSet<Rating> Ratings { get; set; }
    public DbSet<SyncQueue> SyncQueue { get; set; } // Pending changes
    
    protected override void OnConfiguring(DbContextOptionsBuilder options)
    {
        options.UseSqlite("Data Source=local.db");
    }
}

// Offline queuing
var pendingChange = new SyncQueueEntry
{
    Action = "CreateRating",
    EntityType = "Rating",
    Data = JsonConvert.SerializeObject(newRating),
    CreatedAt = DateTime.UtcNow
};
await _offlineDb.SyncQueue.AddAsync(pendingChange);
await _offlineDb.SaveChangesAsync();
```

### SQL Server (Online - Cloud)

```csharp
// BooksContext.cs in Books service
public class BooksContext : DbContext
{
    public DbSet<Book> Books { get; set; }
    public DbSet<Rating> Ratings { get; set; }
    
    protected override void OnModelCreating(ModelBuilder builder)
    {
        builder.Entity<Book>()
            .HasKey(b => b.Id);
        
        builder.Entity<Book>()
            .HasIndex(b => b.Isbn)
            .IsUnique();
    }
}
```

### Data Synchronization Flow

```
Client (SQLite)
    ↓
[Pending mutations queued]
    ↓
[Network available?]
    ↓
SyncService calls API Gateway
    ↓
API Gateway routes to appropriate service
    ↓
Service validates & processes
    ↓
SQL Server updated
    ↓
Confirmation returned to client
    ↓
SQLite SyncQueue cleared
```

### Repository Pattern

```csharp
// Generic Repository
public interface IRepository<T> where T : IEntity
{
    Task<T> GetByIdAsync(int id);
    Task<List<T>> GetAllAsync(int skip, int take);
    Task<T> AddAsync(T entity);
    Task<T> UpdateAsync(T entity);
    Task DeleteAsync(int id);
}

// EF Core Implementation
public class Repository<T> : IRepository<T> where T : class, IEntity
{
    private readonly DbContext _context;
    
    public async Task<T> GetByIdAsync(int id)
    {
        return await _context.Set<T>().FindAsync(id);
    }
}
```

## Advanced Deployment & Integration

### Per-Module Aspire Orchestration

Each microservice has its own Aspire host for independent development and multi-region deployment:
- [Per-Module Aspire Guide](Documentation/Deployment/aspire-per-module.md) - Separate Aspire projects for each service with environment-specific configuration
- [Global Aspire Host](Documentation/Deployment/aspire-per-module.md#global-aspire-host-optional) - Optional central orchestration for full system testing

### Testing Infrastructure

- [Podman Test Module](Documentation/Testing/podman-module.md) - Centralized containerized testing infrastructure (SQL Server, RabbitMQ, Redis, Keycloak, Jaeger, Prometheus) with docker-compose templates and health checks
- [Load Testing & Performance Benchmarks](Documentation/Testing/load-testing-benchmarks.md) - k6 load testing, BenchmarkDotNet code performance, performance thresholds, SLA monitoring, CI/CD integration

### CI/CD Automation

- [GitHub Actions Pipeline](Documentation/.github/workflows/CI-CD-PIPELINE.md) - Automated build, test, security scan, and deployment with conditional logic:
  - Unit tests, integration tests with Podman services
  - SAST scanning (SonarQube + Trivy), dependency vulnerability checking
  - Container image building and security scanning
  - Conditional deployment to Azure, AWS, GCP
  - Slack notifications on completion

### Security Framework

- [WASP Security Implementation](Documentation/Security/wasp-security-framework.md) - Enterprise security compliance:
  - JWT authentication via Keycloak with token validation
  - Role-based and resource-based authorization policies
  - AES-256 data encryption at rest and in transit (TLS 1.3)
  - Input validation (SQL injection, XSS, CSRF prevention)
  - Comprehensive audit logging for all security events
  - Rate limiting (per-user/per-IP) for DDoS protection
  - Secrets management integration (Key Vault, Secrets Manager)
  - Security headers (HSTS, CSP, X-Frame-Options, etc.)

### Service Communication

- [DAPR Integration](Documentation/Architecture/dapr-integration.md) - Distributed Application Runtime for cloud-agnostic microservices:
  - Service-to-service invocation without direct dependencies
  - State management abstraction (Redis, Cosmos, DynamoDB)
  - Pub/Sub messaging with multiple backends (RabbitMQ, Event Hub, Kinesis)
  - Secrets management without code changes
  - Built-in resilience (retry, timeout, circuit breaker)
  - OpenTelemetry distributed tracing

### Cloud-Agnostic Deployment

- [Deployment Guide](Documentation/Deployment/cloud-agnostic-deployment.md) - Deploy to any cloud (Azure, AWS, GCP):
  - Kubernetes manifests for all services, databases, monitoring
  - Terraform infrastructure-as-code with environment variables
  - Helm charts for templated deployments
  - Multi-environment support (dev, staging, production)
  - Auto-scaling, self-healing, health checks
  - Easy rollback and blue-green deployment

## Aspire Orchestration

### Aspire Host Configuration

Centralized Aspire host (optional) orchestrates all services:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Add databases
var booksDb = builder.AddSqlServer("booksdb")
    .AddDatabase("books");

var ratingsDb = builder.AddSqlServer("ratingsdb")
    .AddDatabase("ratings");

// Add services
builder.AddProject<Projects.BookRatings_Services_Books>("books-service")
    .WithReference(booksDb)
    .WithEnvironment("ConnectionStrings__Books", booksDb.ConnectionString);

builder.AddProject<Projects.BookRatings_Services_Ratings>("ratings-service")
    .WithReference(ratingsDb);

// Add gateway
builder.AddProject<Projects.BookRatings_Gateway>("api-gateway")
    .WithReference(booksService)
    .WithReference(ratingsService)
    .WithHttpEndpoint(port: 5000);

// Add web client
builder.AddProject<Projects.BookRatings_Web>("web-client")
    .WithReference(gateway)
    .WithHttpEndpoint(port: 5012);

await builder.Build().RunAsync();
```

### Running with Aspire

```bash
# Runs all services with Aspire Dashboard
dotnet run --project BookRatings.Aspire

# Aspire Dashboard: http://localhost:18888
```

### Aspire Features

- **Service Discovery**: Automatic DNS resolution between services
- **Configuration**: Centralized appsettings per environment
- **Health Monitoring**: Real-time health status for all services
- **Log Aggregation**: View logs from all services in one place
- **Tracing**: Distributed tracing across services

## Configuration Management

### Settings Hierarchy

1. **appsettings.json** - Base/production defaults
2. **appsettings.{Environment}.json** - Environment-specific overrides
3. **User Secrets** (Development) - Sensitive data (not in git)
4. **Environment Variables** - Runtime overrides
5. **Aspire Configuration** - Aspire-specific settings

### Environment-Specific Files

- `appsettings.Development.json` - Development overrides
- `appsettings.Staging.json` - Staging overrides
- `appsettings.Production.json` - Production overrides

### User Secrets (Development Only)

```bash
# Initialize user secrets
dotnet user-secrets init

# Set Keycloak secret
dotnet user-secrets set "Keycloak:ClientSecret" "secret-value"
```

### Configuration Access in Code

```csharp
// In Program.cs
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
var keycloakAuthority = builder.Configuration["Keycloak:Authority"];

// In services
public class BooksService
{
    private readonly IConfiguration _configuration;
    
    public BooksService(IConfiguration configuration)
    {
        _configuration = configuration;
    }
}
```

### Environment Variables

- `ASPNETCORE_ENVIRONMENT` - Current environment (Development, Staging, Production)
- `ASPNETCORE_URLS` - Service URLs (http://localhost:5001)
- `ConnectionStrings__DefaultConnection` - Database connection string
- `Keycloak__Authority` - Keycloak server URL
- `OTEL_EXPORTER_OTLP_ENDPOINT` - OpenTelemetry collector endpoint

## Common Patterns & Recipes

### Create a New Vertical Slice Feature

```csharp
// Features/GetBooks/Request.cs
public class GetBooksRequest : IRequest<List<GetBooksResponse>>
{
    public int Skip { get; set; } = 0;
    public int Take { get; set; } = 10;
    public string SortBy { get; set; } = "title";
}

// Features/GetBooks/Response.cs
public class GetBooksResponse
{
    public int Id { get; set; }
    public string Title { get; set; }
    public string Author { get; set; }
}

// Features/GetBooks/Handler.cs
public class GetBooksHandler : IRequestHandler<GetBooksRequest, List<GetBooksResponse>>
{
    private readonly IRepository<Book> _repository;
    private readonly IMapper _mapper;
    
    public async Task<List<GetBooksResponse>> Handle(
        GetBooksRequest request, 
        CancellationToken cancellationToken)
    {
        var books = await _repository.GetAllAsync(request.Skip, request.Take);
        return _mapper.Map<List<GetBooksResponse>>(books);
    }
}

// Features/GetBooks/GetBooksEndpoint.cs
public static class GetBooksEndpoint
{
    public static void MapGetBooks(this WebApplication app)
    {
        app.MapGet("/api/books", GetBooks)
            .WithName("GetBooks")
            .WithOpenApi()
            .Produces<List<GetBooksResponse>>()
            .RequireAuthorization();
    }
    
    private static async Task<IResult> GetBooks(
        IMediator mediator, 
        GetBooksRequest request)
    {
        var response = await mediator.Send(request);
        return Results.Ok(response);
    }
}
```

### Inject Services

```csharp
// In Program.cs
builder.Services.AddScoped<IBookService, BookService>();
builder.Services.AddScoped<IRatingsService, RatingsService>();
builder.Services.AddScoped(typeof(IRepository<>), typeof(Repository<>));

// In service/handler
public class BooksService
{
    private readonly IRepository<Book> _repository;
    
    public BooksService(IRepository<Book> repository)
    {
        _repository = repository;
    }
}
```

### Add Offline Sync

```csharp
// Services/OfflineSyncService.cs
public class OfflineSyncService
{
    private readonly OfflineDbContext _offlineDb;
    private readonly HttpClient _httpClient;
    
    public async Task SyncChangesAsync()
    {
        var pendingChanges = await _offlineDb.SyncQueue
            .Where(x => !x.IsSynced)
            .ToListAsync();
        
        foreach (var change in pendingChanges)
        {
            try
            {
                var response = await _httpClient.PostAsJsonAsync(
                    $"/api/{change.EntityType.ToLower()}", 
                    change.Data);
                
                if (response.IsSuccessStatusCode)
                {
                    change.IsSynced = true;
                    change.SyncedAt = DateTime.UtcNow;
                }
            }
            catch (HttpRequestException)
            {
                // Retry later
            }
        }
        
        await _offlineDb.SaveChangesAsync();
    }
}
```

### Add Health Check

```csharp
// In Program.cs
builder.Services
    .AddHealthChecks()
    .AddDbContextCheck<BooksContext>()
    .AddHttpHealthCheck("https://api.bookratings.com/health/live")
    .AddCheck<CustomHealthCheck>("CustomCheck");

app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("live")
});

app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
```

### Add Observability

```csharp
// In handler for structured logging
public class GetBooksHandler : IRequestHandler<GetBooksRequest, List<GetBooksResponse>>
{
    private readonly ILogger<GetBooksHandler> _logger;
    
    public async Task<List<GetBooksResponse>> Handle(
        GetBooksRequest request, 
        CancellationToken cancellationToken)
    {
        using var activity = new Activity("GetBooks").Start();
        
        _logger.LogInformation("Fetching {Count} books with skip={Skip}, take={Take}", 
            "requested", request.Skip, request.Take);
        
        try
        {
            var books = await _repository.GetAllAsync(request.Skip, request.Take);
            _logger.LogInformation("Retrieved {BookCount} books", books.Count);
            return _mapper.Map<List<GetBooksResponse>>(books);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error fetching books");
            throw;
        }
    }
}
```

## Architecture Decision Records (ADRs)

### 1. Per-Module Aspire vs Global Aspire
**Decision**: Support both
- **Per-module**: For independent service development
- **Global**: For full-system integration testing
- **Reasoning**: Reduces resource usage during development, supports test isolation

### 2. DAPR vs MassTransit
**Decision**: Use both for different scenarios
- **MassTransit**: Event-driven broadcast (eventual consistency)
- **DAPR**: Service invocation (request-response)
- **Reasoning**: Best tool for each use case, cloud-agnostic with DAPR

### 3. Cloud Provider Selection
**Decision**: Support all three (Azure, AWS, GCP) via Terraform variables
- **Reasoning**: Customer choice flexibility, no lock-in, easier migration

### 4. Secret Management
**Decision**: Use cloud-native vaults (Key Vault, Secrets Manager, Secret Manager)
- **Reasoning**: Each cloud has native, secure, auditable secret management
- **Implementation**: Terraform modules handle provider-specific setup

### 5. Kubernetes vs Managed Services
**Decision**: Use cloud-native managed services (AKS, EKS, GKE) with Kubernetes manifests
- **Reasoning**: Simplified cluster management, auto-scaling, patches handled by cloud

## Important Notes & Gotchas

### Database-Per-Service Pattern
- Each microservice has its own dedicated database (SQL Server for online)
- Services communicate via HTTP or message queue, NOT direct database access
- Never share databases between services
- Use API contracts (DTOs) for service-to-service communication

### Offline-First Synchronization
- Clients queue mutations in SQLite when offline
- SyncService automatically syncs when network is available
- Handle merge conflicts gracefully (last-write-wins or custom logic)
- Test sync scenarios thoroughly (network unavailable, partial sync, etc.)

### Aspire Port Conflicts
- Each service must have unique port
- Check `BookRatings.Aspire/AppHost.cs` for port assignments
- If ports are taken, update appsettings.json in each service

### Keycloak Integration
- Ensure Keycloak is running before starting services
- Validate JWT token expiration handling
- Implement refresh token rotation for long-lived clients
- Test role-based authorization in each endpoint

### Service-to-Service Communication
- Services communicate **asynchronously via events** (MassTransit) - NOT synchronous HTTP
- Each service publishes domain events when state changes
- Other services subscribe to events and update their own state
- Events are durable - if subscriber is offline, messages queue and retry
- Use correlation IDs in events for distributed tracing
- Log events with structured logging for audit trail
- Design for **eventual consistency** - data synchronizes through event stream

### Observability Setup
- Enable OpenTelemetry collection before production (Jaeger, DataDog, or cloud-native APM)
- Configure Prometheus scraping for all services on port 9090
- Set up Grafana dashboards for service health, request latency (p50/p95/p99), error rates
- Integrate with cloud-native monitoring: Application Insights (Azure), CloudWatch (AWS), Cloud Monitoring (GCP)
- DataDog APM recommended for production: Distributed tracing, profiling, real user monitoring

### Multi-Region Deployment
- Use separate Aspire per region with environment-specific configuration (see [aspire-per-module.md](Documentation/Deployment/aspire-per-module.md#multi-region-per-module-orchestration))
- Implement geo-routing at API Gateway using cloud load balancers
- Handle GDPR data residency: EU workloads → EU regions only
- Use Terraform `for_each` loops to provision identical stacks in multiple regions
- Test failover scenarios with chaos engineering

### Cloud-Agnostic Deployment
- Kubernetes manifests in `Deployment/kubernetes/` work on AKS, EKS, GKE (tested on all three)
- Terraform modules abstract cloud-specific resources: `var.cloud_provider` determines provider
- Avoid cloud-specific services: Don't use SQL Azure features, use portable SQL patterns
- Secrets: Each cloud provides different vault services, handled via Terraform modules
- Networking: Use cloud-agnostic network policies, avoid cloud-specific security groups
- Test deployment script `./Deployment/scripts/deploy.sh` on target cloud before production

### DAPR Production Setup
- DAPR control plane must be installed on cluster (handled by Terraform module)
- Each service sidecar auto-injected via annotations
- Components (statestore, pubsub, secrets) must match cloud provider backends
- Production DAPR placement service must be highly available (3+ replicas)
- Monitor DAPR metrics via Prometheus (dashboard in Grafana)

### Testing with Podman
- Use Podman Compose for local integration testing
- Ensure Docker/Podman daemon is running
- Container images must be built before tests run
- Use test fixtures with containerized databases (SQL Server, Redis)

## Deployment

Refer to [Cloud-Agnostic Deployment Guide](Documentation/Deployment/cloud-agnostic-deployment.md) for comprehensive deployment instructions.

### Quick Deployment Commands

```bash
# Deploy to Azure (production)
./Deployment/scripts/deploy.sh azure production eastus

# Deploy to AWS (staging)
./Deployment/scripts/deploy.sh aws staging us-east-1

# Deploy to GCP (development)
./Deployment/scripts/deploy.sh gcp dev us-central1
```

### Deployment Regions

Supported multi-region deployment:
- **US East** (Azure: eastus, AWS: us-east-1, GCP: us-central1)
- **EU West** (Azure: westeurope, AWS: eu-west-1, GCP: europe-west1)
- **APAC** (Azure: southeastasia, AWS: ap-southeast-1, GCP: asia-southeast1)
- **Custom** - Any region supported by cloud provider

### Environment Promotion Pipeline

```
Development → Staging → Production
    ↓
- Per-module Aspire orchestration
- Separate Kubernetes clusters
- Per-region Keycloak realms
- Environment-specific secrets (Key Vault, Secrets Manager, Secret Manager)
- Conditional GitHub Actions deployments
```

## Advanced Features & Integration

### Event-Driven vs DAPR Communication

Choose communication pattern based on use case:

**Event-Driven (MassTransit + RabbitMQ)**
- Best for: Broadcast events to multiple subscribers
- Example: BookCreatedEvent published to Ratings, Admin, Reporting services
- Benefits: Built-in retry, durable queues, event sourcing

**DAPR Service Invocation**
- Best for: Direct service-to-service requests with expected response
- Example: Books Service calls Ratings Service for stats via DAPR
- Benefits: Cloud-agnostic, built-in resilience, service discovery

**Hybrid Approach (Recommended)**
```
Books Service creates book
  ↓
Publishes BookCreatedEvent via MassTransit (async)
  ↓
Ratings Service subscribes (eventual consistency)
Admin Service subscribes (audit log)
Reporting Service subscribes (analytics update)
  ↓
Books Service needs ratings NOW
  ↓
Invokes RatingsService.GetStats via DAPR (sync request-response)
```

### Security Compliance

Every endpoint must enforce:

```csharp
app.MapGet("/api/books/{id}", GetBookById)
    .RequireAuthorization("Reader")          // WASP: Authentication
    .RequireRateLimiting("BookRatings")      // WASP: Rate limiting
    .WithOpenApi()                           // API documentation
    .Produces<BookDto>();                   // Response type
```

Security headers automatically added by middleware:
- Strict-Transport-Security (HSTS)
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- Content-Security-Policy
- X-XSS-Protection

### CI/CD Pipeline Stages

1. **Build & Unit Test** (parallel for each service)
2. **Integration Tests** (with Podman containers)
3. **SAST Security Scan** (SonarQube + Trivy)
4. **Container Image Build** (multi-platform amd64, arm64)
5. **Container Security Scan** (Trivy CVE scanning)
6. **Quality Gate** (all checks must pass)
7. **Conditional Deployment** (to Azure/AWS/GCP based on branch)
8. **Smoke Tests** (verify health endpoints)
9. **Slack Notification** (success/failure alert)

## Typical Development Tasks

### Add a New Microservice

1. Create `Services/NewService/BookRatings.Services.NewService/`
2. Add to `BookRatings.Aspire/AppHost.cs`
3. Implement vertical slices in `Features/`
4. Create minimal API endpoints in `Endpoints/`
5. Add database context in `Data/`
6. Add Dockerfile for containerization
7. Register in API Gateway routes

### Add a New Feature (Vertical Slice)

1. Create feature folder: `Services/Books/BookRatings.Services.Books/Features/YourFeature/`
2. Create `Request.cs`, `Response.cs`, `Handler.cs`, `Validator.cs`
3. Create `YourFeatureEndpoint.cs` with minimal API binding
4. Register in `Program.cs` with MediatR
5. Add tests in `BookRatings.Services.Books.Tests/`

### Add Offline Sync Support

1. Create `Data/OfflineDbContext.cs` with SQLite configuration
2. Implement `Services/OfflineSyncService.cs`
3. Add sync queue tables to track pending changes
4. Register sync service in DI container
5. Call from client app on network availability

### Add Observability

1. Register OpenTelemetry in `Program.cs`
2. Add custom metrics using `System.Diagnostics.Metrics`
3. Configure Prometheus scraping endpoint
4. Create Grafana dashboard for visualization
5. Set up DataDog APM in production

### Add Health Checks

1. Create `CustomHealthCheck.cs` implementing `IHealthCheck`
2. Register in `Program.cs` with `AddHealthChecks()`
3. Map `/health/live` and `/health/ready` endpoints
4. Add checks for database, external services, etc.

### Deploy to Cloud

1. Build Podman images: `podman build -t service:latest -f Dockerfile .`
2. Push to registry: `podman push service:latest registry.example.com/service`
3. Apply Kubernetes manifests: `kubectl apply -f Deployment/kubernetes/`
4. Verify with Helm: `helm install bookratings ./Deployment/helm/bookratings`
5. Monitor with Grafana dashboards

### Configure Keycloak Authentication

1. Set up Keycloak realm and clients
2. Configure OpenID Connect in `Program.cs`
3. Add `RequireAuthorization()` to protected endpoints
4. Implement role-based policies for authorization
5. Test with JWT tokens from Keycloak

## Next Steps for Growth

The application is architected as an enterprise-grade microservices platform. To complete implementation:

### Phase 1: Core Services & Data Layer
- [ ] Implement Books Service with full CRUD operations
- [ ] Implement Ratings Service for user ratings and reviews
- [ ] Implement Users Service for user management
- [ ] Set up SQL Server databases per service
- [ ] Create EF Core migrations for each service
- [ ] Implement repository pattern for data access
- [ ] Add FluentValidation for request validation

### Phase 2: API Gateway & Client Integration
- [ ] Implement API Gateway routing to microservices
- [ ] Add request/response middleware (logging, error handling)
- [ ] Implement rate limiting and CORS policies
- [ ] Create typed HttpClients in Blazor Web
- [ ] Implement offline sync for mobile clients (.NET MAUI)
- [ ] Add WebSocket support for real-time updates (SignalR)

### Phase 3: Authentication & Security
- [ ] Set up Keycloak server and realm
- [ ] Configure OpenID Connect in all services
- [ ] Implement role-based authorization (Admin, Moderator, Reader)
- [ ] Add JWT token validation and refresh logic
- [ ] Implement WASP security policies
- [ ] Add audit logging for sensitive operations
- [ ] Enable TLS 1.3 for all service communication

### Phase 4: Offline & Synchronization
- [ ] Implement SQLite offline database in mobile/web clients
- [ ] Create SyncService for automatic synchronization
- [ ] Handle merge conflicts (last-write-wins strategy)
- [ ] Implement sync queue for offline mutations
- [ ] Add network connectivity detection
- [ ] Test offline scenarios thoroughly

### Phase 5: Admin & Reporting Services
- [ ] Implement Admin Service for user management
- [ ] Add content moderation features
- [ ] Implement Reporting Service for analytics
- [ ] Create report export (CSV, Excel, PDF)
- [ ] Build user activity dashboards
- [ ] Add system configuration endpoints

### Phase 6: Observability & Monitoring
- [ ] Configure OpenTelemetry across all services
- [ ] Set up Prometheus metrics collection
- [ ] Create Grafana dashboards (performance, errors, uptime)
- [ ] Implement Watchdog service for health checks
- [ ] Configure DataDog APM for production monitoring
- [ ] Set up structured logging with correlation IDs
- [ ] Create alerting rules for critical metrics

### Phase 7: Testing & Quality
- [ ] Create unit tests for all services
- [ ] Implement integration tests with Podman containers
- [ ] Add E2E tests with Playwright
- [ ] Set up CI/CD pipeline (GitHub Actions or Azure DevOps)
- [ ] Add code coverage reports
- [ ] Implement security scanning (SAST/DAST)
- [ ] Performance load testing

### Phase 8: Containerization & Deployment
- [ ] Create Dockerfile for each service
- [ ] Build Podman images with multi-platform support
- [ ] Create docker-compose.yml for local development
- [ ] Write Kubernetes manifests for all services
- [ ] Create Helm charts for deployment
- [ ] Set up Terraform for infrastructure provisioning
- [ ] Implement blue-green deployment strategy

### Phase 9: Multi-Region & High Availability
- [ ] Configure Aspire per region (US East, EU West, APAC)
- [ ] Implement data replication across regions
- [ ] Set up geo-routing at API Gateway
- [ ] Implement GDPR compliance for EU region
- [ ] Add failover and disaster recovery
- [ ] Test multi-region scenarios

### Phase 10: Client Applications
- [ ] Build Blazor Server web application
- [ ] Implement .NET MAUI mobile app (iOS/Android)
- [ ] Add offline-first support in mobile app
- [ ] Implement push notifications
- [ ] Build responsive UI with Bootstrap/TailwindCSS
- [ ] Add accessibility features (WCAG 2.1)

## Useful References

- [ASP.NET Core Blazor Documentation](https://learn.microsoft.com/en-us/aspnet/core/blazor)
- [Blazor Component Class Libraries](https://learn.microsoft.com/en-us/aspnet/core/blazor/class-libraries)
- [Entity Framework Core Documentation](https://learn.microsoft.com/en-us/ef/core/)
- [.NET Aspire Documentation](https://learn.microsoft.com/en-us/dotnet/aspire/)
- [OpenTelemetry .NET Documentation](https://opentelemetry.io/docs/instrumentation/net/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [MassTransit Documentation](https://masstransit.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [Podman Documentation](https://docs.podman.io/)
