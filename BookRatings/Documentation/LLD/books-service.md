# Books Service - Low-Level Design

## Overview

The **Books Service** is responsible for managing book catalog, metadata, and core book operations across the BookRatings platform. It implements Clean Architecture with Vertical Slice organization.

## Project Structure

### C# Projects (.csproj)

```
Services/Books/
├── BookRatings.Services.Books/
│   ├── BookRatings.Services.Books.csproj        # Main service project
│   ├── Program.cs                               # Startup & DI configuration
│   ├── Core/
│   │   └── Domain/
│   │       ├── Book.cs                          # Book aggregate root
│   │       ├── BookException.cs                 # Domain exceptions
│   │       └── ValueObjects/
│   │           ├── Isbn.cs
│   │           └── BookRating.cs
│   ├── Features/
│   │   ├── GetBooks/
│   │   │   ├── Request.cs
│   │   │   ├── Response.cs
│   │   │   ├── Handler.cs
│   │   │   ├── Validator.cs
│   │   │   ├── Mapper.cs
│   │   │   └── GetBooksEndpoint.cs
│   │   ├── GetBookById/
│   │   ├── CreateBook/
│   │   ├── UpdateBook/
│   │   ├── DeleteBook/
│   │   ├── SearchBooks/
│   │   └── FilterBooksByCategory/
│   ├── Data/
│   │   ├── BooksContext.cs                      # EF Core DbContext
│   │   ├── Configurations/
│   │   │   └── BookConfiguration.cs
│   │   └── Migrations/
│   │       └── *.cs
│   ├── Services/
│   │   ├── BookService.cs
│   │   └── SearchService.cs
│   ├── Endpoints/
│   │   └── BookEndpoints.cs
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   └── appsettings.Production.json
│
├── BookRatings.Services.Books.Database/         # SQL Server project
│   ├── BookRatings.Services.Books.Database.sqlproj
│   ├── dbo/
│   │   ├── Tables/
│   │   │   ├── Books.sql
│   │   │   ├── BookCategories.sql
│   │   │   └── BookAuthors.sql
│   │   ├── Views/
│   │   │   └── vw_BookStats.sql
│   │   ├── StoredProcedures/
│   │   │   ├── sp_GetBooksByCategory.sql
│   │   │   └── sp_SearchBooks.sql
│   │   └── Indexes/
│   │       ├── IX_Books_ISBN.sql
│   │       └── IX_Books_Title.sql
│   ├── Pre-Deployment/
│   │   └── Script.PreDeployment.sql
│   ├── Post-Deployment/
│   │   └── Script.PostDeployment.sql
│   └── Migrations/
│       └── *.sql
│
└── BookRatings.Services.Books.Tests/
    ├── BookRatings.Services.Books.Tests.csproj
    ├── Unit/
    │   ├── Features/
    │   │   ├── GetBooksTests.cs
    │   │   ├── CreateBookTests.cs
    │   │   └── SearchBooksTests.cs
    │   └── Services/
    │       └── BookServiceTests.cs
    ├── Integration/
    │   ├── Fixtures/
    │   │   ├── BooksContextFixture.cs
    │   │   ├── SqlServerFixture.cs
    │   │   └── PodmanContainerFixture.cs
    │   ├── Features/
    │   │   ├── GetBooksIntegrationTests.cs
    │   │   ├── CreateBookIntegrationTests.cs
    │   │   └── SearchBooksIntegrationTests.cs
    │   ├── Endpoints/
    │   │   └── BooksEndpointTests.cs
    │   └── docker-compose.yml              # Podman test containers
    └── E2E/
        └── BooksApiE2ETests.cs
```

### .csproj Configuration

**BookRatings.Services.Books.csproj**:
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <InvariantGlobalization>false</InvariantGlobalization>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="10.0.0" />
    <PackageReference Include="MassTransit" Version="8.1.0" />
    <PackageReference Include="MassTransit.RabbitMQ" Version="8.1.0" />
    <PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.7.0" />
    <PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.7.0" />
    <PackageReference Include="FluentValidation" Version="11.8.0" />
    <PackageReference Include="AutoMapper.Extensions.Microsoft.DependencyInjection" Version="12.0.1" />
    <PackageReference Include="Keycloak.Net" Version="3.12.0" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\Shared\BookRatings.Shared.Domain\BookRatings.Shared.Domain.csproj" />
    <ProjectReference Include="..\..\Shared\BookRatings.Shared.Infrastructure\BookRatings.Shared.Infrastructure.csproj" />
  </ItemGroup>
</Project>
```

### .sqlproj Configuration

**BookRatings.Services.Books.Database.sqlproj**:
```xml
<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" xmlns="http://schemas.microsoft.com/developer/msbuild/2003" ToolsVersion="4.0">
  <PropertyGroup>
    <Configuration Condition=" '$(Configuration)' == '' ">Debug</Configuration>
    <Platform Condition=" '$(Platform)' == '' ">AnyCPU</Platform>
    <Name>BookRatings.Services.Books.Database</Name>
    <SchemaVersion>2.0</SchemaVersion>
    <ProjectVersion>4.1</ProjectVersion>
    <ProjectGuid>{12345678-1234-1234-1234-123456789012}</ProjectGuid>
    <DSP>Microsoft.Data.Tools.Schema.Sql.Sql150DatabaseSchemaProvider</DSP>
    <GenerateCreateScript>True</GenerateCreateScript>
    <TargetDatabaseSet>True</TargetDatabaseSet>
    <DefaultCollation>SQL_Latin1_General_CP1_CI_AS</DefaultCollation>
  </PropertyGroup>
  
  <PropertyGroup Condition=" '$(Configuration)|$(Platform)' == 'Release|AnyCPU' ">
    <OutputPath>bin\Release\</OutputPath>
    <BuildScriptName>BooksDB.sql</BuildScriptName>
    <TreatWarningsAsErrors>False</TreatWarningsAsErrors>
    <DebugType>pdb</DebugType>
    <Optimize>true</Optimize>
    <DefineDebug>false</DefineDebug>
    <DefineTrace>true</DefineTrace>
  </PropertyGroup>

  <ItemGroup>
    <Build Include="dbo\Tables\Books.sql" />
    <Build Include="dbo\Tables\BookCategories.sql" />
    <Build Include="dbo\Tables\BookAuthors.sql" />
    <Build Include="dbo\Views\vw_BookStats.sql" />
    <Build Include="dbo\StoredProcedures\sp_GetBooksByCategory.sql" />
    <Build Include="dbo\Indexes\IX_Books_ISBN.sql" />
  </ItemGroup>

  <ItemGroup>
    <PreDeploy Include="Pre-Deployment\Script.PreDeployment.sql" />
    <PostDeploy Include="Post-Deployment\Script.PostDeployment.sql" />
  </ItemGroup>
</Project>
```

## Database Schema

### Books Table

```sql
CREATE TABLE [dbo].[Books] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [Isbn] VARCHAR(20) UNIQUE NOT NULL,
    [Title] NVARCHAR(500) NOT NULL,
    [Author] NVARCHAR(250) NOT NULL,
    [Publisher] NVARCHAR(250),
    [PublicationDate] DATE,
    [Description] NVARCHAR(MAX),
    [Pages] INT,
    [Language] VARCHAR(10) DEFAULT 'en-US',
    [CategoryId] INT FOREIGN KEY REFERENCES [dbo].[BookCategories]([Id]),
    [AverageRating] DECIMAL(3,2) DEFAULT 0,
    [TotalRatings] INT DEFAULT 0,
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [IsDeleted] BIT DEFAULT 0
);

CREATE TABLE [dbo].[BookCategories] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [Name] NVARCHAR(100) NOT NULL,
    [Description] NVARCHAR(500),
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE [dbo].[BookAuthors] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [BookId] INT FOREIGN KEY REFERENCES [dbo].[Books]([Id]),
    [AuthorName] NVARCHAR(250) NOT NULL,
    [Role] NVARCHAR(50)
);
```

### DACPAC Generation

```bash
# Build DACPAC file
msbuild BookRatings.Services.Books.Database.sqlproj /t:Build /p:Configuration=Release

# Deploy DACPAC to SQL Server
sqlpackage /Action:Publish \
  /SourceFile:bin\Release\BookRatings.Services.Books.Database.dacpac \
  /TargetServerName:localhost \
  /TargetDatabaseName:BookRatings_Books \
  /p:VerifyDeployment=True
```

## Vertical Slices (Features)

### GetBooks Slice

**Request**:
```csharp
public class GetBooksRequest : IRequest<List<GetBooksResponse>>
{
    public int Skip { get; set; } = 0;
    public int Take { get; set; } = 10;
    public string? SortBy { get; set; } = "title";
    public string? SearchTerm { get; set; }
    public int? CategoryId { get; set; }
    public string Language { get; set; } = "en-US";
}
```

**Handler**:
```csharp
public class GetBooksHandler : IRequestHandler<GetBooksRequest, List<GetBooksResponse>>
{
    private readonly BooksContext _context;
    private readonly IMapper _mapper;
    private readonly ILogger<GetBooksHandler> _logger;

    public async Task<List<GetBooksResponse>> Handle(
        GetBooksRequest request, 
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Fetching books with filter: {@Filter}", request);
        
        var query = _context.Books
            .AsNoTracking()
            .Where(b => !b.IsDeleted);

        if (!string.IsNullOrWhiteSpace(request.SearchTerm))
        {
            query = query.Where(b => b.Title.Contains(request.SearchTerm) || 
                                     b.Author.Contains(request.SearchTerm));
        }

        if (request.CategoryId.HasValue)
        {
            query = query.Where(b => b.CategoryId == request.CategoryId);
        }

        var books = await query
            .OrderBy(b => request.SortBy == "rating" ? b.AverageRating : b.Title)
            .Skip(request.Skip)
            .Take(request.Take)
            .ToListAsync(cancellationToken);

        return _mapper.Map<List<GetBooksResponse>>(books);
    }
}
```

### CreateBook Slice

Publishes `BookCreatedEvent` for other services:

```csharp
public class CreateBookHandler : IRequestHandler<CreateBookRequest, CreateBookResponse>
{
    private readonly BooksContext _context;
    private readonly IPublishEndpoint _publishEndpoint;
    private readonly IMapper _mapper;

    public async Task<CreateBookResponse> Handle(
        CreateBookRequest request, 
        CancellationToken cancellationToken)
    {
        var book = new Book
        {
            Isbn = request.Isbn,
            Title = request.Title,
            Author = request.Author,
            Publisher = request.Publisher,
            Description = request.Description,
            Language = request.Language ?? "en-US"
        };

        await _context.Books.AddAsync(book, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);

        // Publish event
        await _publishEndpoint.Publish(new BookCreatedEvent
        {
            BookId = book.Id,
            Title = book.Title,
            Author = book.Author,
            Isbn = book.Isbn,
            Language = book.Language,
            CreatedAt = DateTime.UtcNow
        }, cancellationToken);

        return _mapper.Map<CreateBookResponse>(book);
    }
}
```

## Events Published

- **BookCreatedEvent** - New book added to catalog
- **BookUpdatedEvent** - Book details modified
- **BookDeletedEvent** - Book removed from catalog
- **BookRatingUpdatedEvent** - Average rating recalculated

## Integration Tests with Podman

### docker-compose.yml

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
    volumes:
      - sqlserver_data:/var/opt/mssql
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
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  sqlserver_data:
```

### Integration Test Fixture

```csharp
public class SqlServerFixture : IAsyncLifetime
{
    private readonly DockerContainer _container;
    public string ConnectionString { get; private set; }

    public SqlServerFixture()
    {
        _container = new ContainerBuilder()
            .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
            .WithEnvironment("SA_PASSWORD", "YourPassword123!")
            .WithEnvironment("ACCEPT_EULA", "Y")
            .WithPortBinding(1433, 1433)
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        
        // Wait for SQL Server to be ready
        await Task.Delay(5000);
        
        ConnectionString = "Server=localhost,1433;User Id=sa;Password=YourPassword123!;Database=BooksTest;TrustServerCertificate=true;";
        
        // Run migrations
        using var context = new BooksContext(new DbContextOptionsBuilder<BooksContext>()
            .UseSqlServer(ConnectionString)
            .Options);
        
        await context.Database.MigrateAsync();
    }

    public async Task DisposeAsync()
    {
        await _container.StopAsync();
    }
}

public class GetBooksIntegrationTests : IAsyncLifetime
{
    private readonly SqlServerFixture _fixture = new();
    private BooksContext _context;

    public async Task InitializeAsync() => await _fixture.InitializeAsync();
    public async Task DisposeAsync() => await _fixture.DisposeAsync();

    [Fact]
    public async Task GetBooks_WithValidRequest_ReturnsBooks()
    {
        // Arrange
        var book = new Book { Title = "Test Book", Author = "Test Author", Isbn = "123-456" };
        _context.Books.Add(book);
        await _context.SaveChangesAsync();

        var handler = new GetBooksHandler(_context, new Mapper(...), new Logger<GetBooksHandler>(...));
        var request = new GetBooksRequest { Skip = 0, Take = 10 };

        // Act
        var result = await handler.Handle(request, CancellationToken.None);

        // Assert
        Assert.NotEmpty(result);
        Assert.Single(result);
    }
}
```

## Global Language Support (Localization)

### Resource Files

```
BookRatings.Services.Books/
└── Resources/
    ├── Messages.resx                    # Default (English)
    ├── Messages.fr-FR.resx              # French
    ├── Messages.de-DE.resx              # German
    ├── Messages.es-ES.resx              # Spanish
    ├── Messages.ja-JP.resx              # Japanese
    ├── Messages.zh-CN.resx              # Simplified Chinese
    └── Messages.pt-BR.resx              # Brazilian Portuguese
```

### Localization Configuration

```csharp
// In Program.cs
var supportedCultures = new[] 
{ 
    new CultureInfo("en-US"),
    new CultureInfo("fr-FR"),
    new CultureInfo("de-DE"),
    new CultureInfo("es-ES"),
    new CultureInfo("ja-JP"),
    new CultureInfo("zh-CN"),
    new CultureInfo("pt-BR")
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
    
    // Add query string provider for language switching
    options.RequestCultureProviders.Insert(0, new QueryStringRequestCultureProvider());
    options.RequestCultureProviders.Insert(1, new AcceptLanguageHeaderRequestCultureProvider());
});

app.UseRequestLocalization();
```

### Usage in Responses

```csharp
public class GetBooksResponse
{
    public int Id { get; set; }
    public string Title { get; set; }
    public string Author { get; set; }
    
    // Localized fields
    public string LocalizedTitle { get; set; }
    public string LocalizedAuthor { get; set; }
}
```

### Example Localized Validation

```csharp
public class CreateBookValidator : AbstractValidator<CreateBookRequest>
{
    private readonly IStringLocalizer<CreateBookValidator> _localizer;

    public CreateBookValidator(IStringLocalizer<CreateBookValidator> localizer)
    {
        _localizer = localizer;

        RuleFor(x => x.Title)
            .NotEmpty()
            .WithMessage(_localizer["Title_Required"])
            .MaximumLength(500)
            .WithMessage(_localizer["Title_MaxLength"]);

        RuleFor(x => x.Author)
            .NotEmpty()
            .WithMessage(_localizer["Author_Required"]);

        RuleFor(x => x.Isbn)
            .Matches(@"^\d{3}-\d{10}$")
            .WithMessage(_localizer["Isbn_Invalid"]);
    }
}
```

## API Endpoints

```csharp
var group = app.MapGroup("/api/books")
    .WithName("Books")
    .WithOpenApi()
    .RequireAuthorization();

group.MapGet("/", GetBooks)
    .WithName("GetBooks")
    .WithSummary("Get all books with optional filtering")
    .Produces<List<GetBooksResponse>>(StatusCodes.Status200OK)
    .Produces(StatusCodes.Status401Unauthorized);

group.MapGet("/{id}", GetBookById)
    .WithName("GetBookById")
    .Produces<GetBookResponse>(StatusCodes.Status200OK)
    .Produces(StatusCodes.Status404NotFound);

group.MapPost("/", CreateBook)
    .WithName("CreateBook")
    .Accepts<CreateBookRequest>("application/json")
    .Produces<CreateBookResponse>(StatusCodes.Status201Created)
    .RequireAuthorization(policy => policy.RequireRole("Admin", "Editor"));

group.MapPut("/{id}", UpdateBook)
    .WithName("UpdateBook")
    .Produces(StatusCodes.Status204NoContent);

group.MapDelete("/{id}", DeleteBook)
    .WithName("DeleteBook")
    .Produces(StatusCodes.Status204NoContent)
    .RequireAuthorization(policy => policy.RequireRole("Admin"));
```

## Configuration (appsettings.json)

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=BookRatings_Books;Trusted_Connection=true;"
  },
  "Keycloak": {
    "Authority": "https://keycloak.localhost/realms/bookratings",
    "ClientId": "books-service",
    "ClientSecret": "${Keycloak:ClientSecret}"
  },
  "MassTransit": {
    "Host": "rabbitmq://localhost",
    "VirtualHost": "/"
  },
  "OpenTelemetry": {
    "ExportEndpoint": "http://localhost:4317"
  },
  "AllowedHosts": "*"
}
```

## Build & Test Commands

```bash
# Build Books Service
dotnet build Services/Books/

# Run unit tests
dotnet test Services/Books/BookRatings.Services.Books.Tests/ --filter "Category=Unit"

# Run integration tests with Podman
cd Services/Books/BookRatings.Services.Books.Tests/
docker-compose up -d
dotnet test --filter "Category=Integration"
docker-compose down

# Build DACPAC
msbuild Services/Books/BookRatings.Services.Books.Database.sqlproj /t:Build /p:Configuration=Release

# Deploy database
sqlpackage /Action:Publish /SourceFile:Services/Books/bin/Release/BookRatings.Services.Books.Database.dacpac /TargetServerName:localhost /TargetDatabaseName:BookRatings_Books

# Run Books Service locally
dotnet run --project Services/Books/BookRatings.Services.Books --launch-profile https
```
