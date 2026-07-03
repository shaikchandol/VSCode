# Ratings Service - Low-Level Design

## Overview

The **Ratings Service** manages user ratings, reviews, and aggregated rating statistics for books. It handles rating submissions, updates, and publishes events for rating changes.

## Project Structure

### C# Projects (.csproj)

```
Services/Ratings/
├── BookRatings.Services.Ratings/
│   ├── BookRatings.Services.Ratings.csproj
│   ├── Program.cs
│   ├── Core/
│   │   └── Domain/
│   │       ├── Rating.cs                 # Rating aggregate root
│   │       ├── Review.cs
│   │       ├── RatingException.cs
│   │       └── ValueObjects/
│   │           ├── RatingScore.cs        # 1-5 scale
│   │           └── ReviewText.cs
│   ├── Features/
│   │   ├── SubmitRating/
│   │   │   ├── Request.cs
│   │   │   ├── Response.cs
│   │   │   ├── Handler.cs
│   │   │   ├── Validator.cs
│   │   │   ├── Mapper.cs
│   │   │   └── SubmitRatingEndpoint.cs
│   │   ├── GetRatings/
│   │   ├── GetRatingById/
│   │   ├── UpdateRating/
│   │   ├── DeleteRating/
│   │   └── GetBookAverageRating/
│   ├── Data/
│   │   ├── RatingsContext.cs
│   │   ├── Configurations/
│   │   │   └── RatingConfiguration.cs
│   │   └── Migrations/
│   ├── Services/
│   │   ├── RatingService.cs
│   │   └── RatingAggregationService.cs
│   ├── EventConsumers/
│   │   ├── BookCreatedEventConsumer.cs   # Subscribe to book events
│   │   └── RatingDeletedEventConsumer.cs
│   ├── Endpoints/
│   │   └── RatingsEndpoints.cs
│   ├── appsettings.json
│   └── appsettings.Production.json
│
├── BookRatings.Services.Ratings.Database/
│   ├── BookRatings.Services.Ratings.Database.sqlproj
│   ├── dbo/
│   │   ├── Tables/
│   │   │   ├── Ratings.sql
│   │   │   ├── Reviews.sql
│   │   │   └── RatingStatistics.sql
│   │   ├── Views/
│   │   │   └── vw_RatingTrends.sql
│   │   ├── StoredProcedures/
│   │   │   ├── sp_GetAverageRating.sql
│   │   │   ├── sp_UpdateRatingStats.sql
│   │   │   └── sp_GetTopRatedBooks.sql
│   │   └── Indexes/
│   │       ├── IX_Ratings_BookId.sql
│   │       └── IX_Ratings_UserId.sql
│   ├── Pre-Deployment/Script.PreDeployment.sql
│   ├── Post-Deployment/Script.PostDeployment.sql
│   └── Migrations/
│
└── BookRatings.Services.Ratings.Tests/
    ├── BookRatings.Services.Ratings.Tests.csproj
    ├── Unit/
    │   ├── Features/
    │   │   ├── SubmitRatingTests.cs
    │   │   ├── GetRatingsTests.cs
    │   │   └── RatingValidationTests.cs
    │   └── Services/
    │       └── RatingAggregationServiceTests.cs
    ├── Integration/
    │   ├── Fixtures/
    │   │   ├── RatingsContextFixture.cs
    │   │   └── PodmanContainerFixture.cs
    │   ├── Features/
    │   │   ├── SubmitRatingIntegrationTests.cs
    │   │   └── GetRatingsIntegrationTests.cs
    │   ├── Endpoints/
    │   │   └── RatingsEndpointTests.cs
    │   └── docker-compose.yml
    └── E2E/
        └── RatingsApiE2ETests.cs
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
    <PackageReference Include="Microsoft.EntityFrameworkCore.SqlServer" Version="10.0.0" />
    <PackageReference Include="MassTransit" Version="8.1.0" />
    <PackageReference Include="MassTransit.RabbitMQ" Version="8.1.0" />
    <PackageReference Include="FluentValidation" Version="11.8.0" />
    <PackageReference Include="AutoMapper.Extensions.Microsoft.DependencyInjection" Version="12.0.1" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\Shared\BookRatings.Shared.Contracts\BookRatings.Shared.Contracts.csproj" />
  </ItemGroup>
</Project>
```

## Database Schema

### Ratings Table

```sql
CREATE TABLE [dbo].[Ratings] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [BookId] INT NOT NULL,
    [UserId] NVARCHAR(MAX) NOT NULL,
    [Score] INT NOT NULL,
    [ReviewTitle] NVARCHAR(200),
    [ReviewText] NVARCHAR(MAX),
    [IsVerifiedPurchase] BIT DEFAULT 0,
    [HelpfulCount] INT DEFAULT 0,
    [UnhelpfulCount] INT DEFAULT 0,
    [Language] VARCHAR(10) DEFAULT 'en-US',
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [IsDeleted] BIT DEFAULT 0
);

CREATE TABLE [dbo].[RatingStatistics] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [BookId] INT UNIQUE NOT NULL,
    [AverageScore] DECIMAL(3,2) DEFAULT 0,
    [TotalRatings] INT DEFAULT 0,
    [FiveStarCount] INT DEFAULT 0,
    [FourStarCount] INT DEFAULT 0,
    [ThreeStarCount] INT DEFAULT 0,
    [TwoStarCount] INT DEFAULT 0,
    [OneStarCount] INT DEFAULT 0,
    [LastUpdated] DATETIME2 DEFAULT GETUTCDATE()
);

-- Index for performance
CREATE INDEX [IX_Ratings_BookId] ON [dbo].[Ratings]([BookId]);
CREATE INDEX [IX_Ratings_UserId] ON [dbo].[Ratings]([UserId]);
CREATE INDEX [IX_Ratings_CreatedAt] ON [dbo].[Ratings]([CreatedAt]);
```

## Vertical Slices (Features)

### SubmitRating Slice

```csharp
public class SubmitRatingRequest : IRequest<SubmitRatingResponse>
{
    public int BookId { get; set; }
    public string UserId { get; set; }
    public int Score { get; set; }          // 1-5
    public string? ReviewTitle { get; set; }
    public string? ReviewText { get; set; }
    public string Language { get; set; } = "en-US";
}

public class SubmitRatingValidator : AbstractValidator<SubmitRatingRequest>
{
    public SubmitRatingValidator(IStringLocalizer<SubmitRatingValidator> localizer)
    {
        RuleFor(x => x.BookId)
            .GreaterThan(0)
            .WithMessage(localizer["BookId_Required"]);

        RuleFor(x => x.Score)
            .InclusiveBetween(1, 5)
            .WithMessage(localizer["Score_Range"]);

        RuleFor(x => x.ReviewText)
            .MaximumLength(5000)
            .WithMessage(localizer["ReviewText_MaxLength"]);
    }
}

public class SubmitRatingHandler : IRequestHandler<SubmitRatingRequest, SubmitRatingResponse>
{
    private readonly RatingsContext _context;
    private readonly IPublishEndpoint _publishEndpoint;
    private readonly IMapper _mapper;
    private readonly ILogger<SubmitRatingHandler> _logger;

    public async Task<SubmitRatingResponse> Handle(
        SubmitRatingRequest request,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Submitting rating for book {BookId} by user {UserId}", 
            request.BookId, request.UserId);

        var rating = new Rating
        {
            BookId = request.BookId,
            UserId = request.UserId,
            Score = request.Score,
            ReviewTitle = request.ReviewTitle,
            ReviewText = request.ReviewText,
            Language = request.Language
        };

        await _context.Ratings.AddAsync(rating, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);

        // Update statistics
        await UpdateRatingStatistics(request.BookId, cancellationToken);

        // Publish event
        await _publishEndpoint.Publish(new RatingSubmittedEvent
        {
            RatingId = rating.Id,
            BookId = request.BookId,
            UserId = request.UserId,
            Score = request.Score,
            Language = request.Language,
            CreatedAt = DateTime.UtcNow
        }, cancellationToken);

        _logger.LogInformation("Rating {RatingId} submitted successfully", rating.Id);

        return _mapper.Map<SubmitRatingResponse>(rating);
    }

    private async Task UpdateRatingStatistics(int bookId, CancellationToken cancellationToken)
    {
        var ratings = await _context.Ratings
            .Where(r => r.BookId == bookId && !r.IsDeleted)
            .ToListAsync(cancellationToken);

        var stats = await _context.RatingStatistics
            .FirstOrDefaultAsync(s => s.BookId == bookId, cancellationToken)
            ?? new RatingStatistics { BookId = bookId };

        stats.AverageScore = (decimal)ratings.Average(r => r.Score);
        stats.TotalRatings = ratings.Count;
        stats.FiveStarCount = ratings.Count(r => r.Score == 5);
        stats.FourStarCount = ratings.Count(r => r.Score == 4);
        stats.ThreeStarCount = ratings.Count(r => r.Score == 3);
        stats.TwoStarCount = ratings.Count(r => r.Score == 2);
        stats.OneStarCount = ratings.Count(r => r.Score == 1);
        stats.LastUpdated = DateTime.UtcNow;

        if (stats.Id == 0)
            await _context.RatingStatistics.AddAsync(stats, cancellationToken);
        else
            _context.RatingStatistics.Update(stats);

        await _context.SaveChangesAsync(cancellationToken);
    }
}
```

### Event Consumer Example

```csharp
public class BookCreatedEventConsumer : IConsumer<BookCreatedEvent>
{
    private readonly RatingsContext _context;
    private readonly ILogger<BookCreatedEventConsumer> _logger;

    public async Task Consume(ConsumeContext<BookCreatedEvent> context)
    {
        _logger.LogInformation("Book created event received: {BookId}", context.Message.BookId);

        var bookStats = new RatingStatistics
        {
            BookId = context.Message.BookId,
            AverageScore = 0,
            TotalRatings = 0
        };

        await _context.RatingStatistics.AddAsync(bookStats);
        await _context.SaveChangesAsync();
    }
}
```

## Events Published

- **RatingSubmittedEvent** - New rating added
- **RatingUpdatedEvent** - Rating modified
- **RatingDeletedEvent** - Rating removed
- **RatingStatisticsUpdatedEvent** - Average rating recalculated

## Events Consumed

- **BookCreatedEvent** - Initialize rating statistics for new book
- **BookDeletedEvent** - Cascade delete related ratings

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
      - "1434:1433"  # Different port for Ratings DB
    healthcheck:
      test: ["CMD", "/opt/mssql-tools/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", "YourPassword123!", "-Q", "SELECT 1"]
      interval: 10s
      timeout: 3s
      retries: 5

  rabbitmq:
    image: rabbitmq:3.12-management
    ports:
      - "5673:5672"
      - "15673:15672"
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

## Global Language Support

### Supported Languages

- **English (en-US)** - Default
- **French (fr-FR)**
- **German (de-DE)**
- **Spanish (es-ES)**
- **Japanese (ja-JP)**
- **Simplified Chinese (zh-CN)**
- **Portuguese (pt-BR)**

### Localization in Rating Responses

```csharp
public class SubmitRatingResponse
{
    public int Id { get; set; }
    public int BookId { get; set; }
    public int Score { get; set; }
    public string ReviewTitle { get; set; }
    public string ReviewText { get; set; }
    public string Language { get; set; }
    public DateTime CreatedAt { get; set; }
    
    // Localized message
    public string LocalizedMessage { get; set; }
}
```

## API Endpoints

```csharp
var group = app.MapGroup("/api/ratings")
    .WithName("Ratings")
    .WithOpenApi()
    .RequireAuthorization();

group.MapPost("/", SubmitRating)
    .WithName("SubmitRating")
    .WithSummary("Submit a rating for a book")
    .Accepts<SubmitRatingRequest>("application/json")
    .Produces<SubmitRatingResponse>(StatusCodes.Status201Created);

group.MapGet("/book/{bookId}", GetBookRatings)
    .WithName("GetBookRatings")
    .WithSummary("Get all ratings for a book")
    .Produces<List<GetRatingsResponse>>();

group.MapGet("/{id}", GetRatingById)
    .WithName("GetRatingById")
    .Produces<GetRatingsResponse>();

group.MapPut("/{id}", UpdateRating)
    .WithName("UpdateRating")
    .Produces(StatusCodes.Status204NoContent);

group.MapDelete("/{id}", DeleteRating)
    .WithName("DeleteRating")
    .Produces(StatusCodes.Status204NoContent);

group.MapGet("/book/{bookId}/statistics", GetRatingStatistics)
    .WithName("GetRatingStatistics")
    .AllowAnonymous()
    .Produces<RatingStatisticsResponse>();
```

## Configuration

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=BookRatings_Ratings;Trusted_Connection=true;"
  },
  "MassTransit": {
    "Host": "rabbitmq://localhost",
    "VirtualHost": "/"
  },
  "AllowedHosts": "*"
}
```

## Build & Test Commands

```bash
# Build Ratings Service
dotnet build Services/Ratings/

# Run unit tests
dotnet test Services/Ratings/BookRatings.Services.Ratings.Tests/ --filter "Category=Unit"

# Run integration tests with Podman
cd Services/Ratings/BookRatings.Services.Ratings.Tests/
docker-compose up -d
dotnet test --filter "Category=Integration"
docker-compose down

# Deploy database
msbuild Services/Ratings/BookRatings.Services.Ratings.Database.sqlproj /t:Build /p:Configuration=Release
sqlpackage /Action:Publish /SourceFile:Services/Ratings/bin/Release/BookRatings.Services.Ratings.Database.dacpac /TargetServerName:localhost /TargetDatabaseName:BookRatings_Ratings
```
