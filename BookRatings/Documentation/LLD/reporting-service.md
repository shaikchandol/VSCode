# Reporting Service - Low-Level Design

## Overview

The **Reporting Service** provides analytics, reporting, and data export capabilities. It aggregates data from other services via events and generates insights about books, ratings, users, and trends.

## Project Structure

### C# Projects (.csproj)

```
Services/Reporting/
├── BookRatings.Services.Reporting/
│   ├── BookRatings.Services.Reporting.csproj
│   ├── Program.cs
│   ├── Core/
│   │   └── Domain/
│   │       ├── BookAnalytics.cs
│   │       ├── UserAnalytics.cs
│   │       ├── RatingTrends.cs
│   │       └── Report.cs
│   ├── Features/
│   │   ├── BookAnalytics/
│   │   │   ├── GetTopRatedBooks/
│   │   │   ├── GetBookTrends/
│   │   │   └── GetCategoryAnalytics/
│   │   ├── UserAnalytics/
│   │   │   ├── GetActiveUsers/
│   │   │   ├── GetUserActivity/
│   │   │   └── GetUserEngagement/
│   │   ├── RatingTrends/
│   │   │   ├── GetRatingTrends/
│   │   │   ├── GetGenreTrends/
│   │   │   └── GetTimeSeries/
│   │   └── ExportReports/
│   │       ├── ExportToCsv/
│   │       ├── ExportToExcel/
│   │       └── ExportToPdf/
│   ├── Data/
│   │   ├── ReportingContext.cs
│   │   ├── Configurations/
│   │   │   └── ReportConfiguration.cs
│   │   └── Migrations/
│   ├── Services/
│   │   ├── AnalyticsService.cs
│   │   ├── ExportService.cs
│   │   ├── TrendAnalysisService.cs
│   │   └── ReportGenerationService.cs
│   ├── EventConsumers/
│   │   ├── BookCreatedEventConsumer.cs
│   │   ├── RatingSubmittedEventConsumer.cs
│   │   ├── UserRegisteredEventConsumer.cs
│   │   └── ReviewModerationEventConsumer.cs
│   ├── Endpoints/
│   │   ├── AnalyticsEndpoints.cs
│   │   ├── TrendsEndpoints.cs
│   │   └── ReportEndpoints.cs
│   ├── appsettings.json
│   └── appsettings.Production.json
│
├── BookRatings.Services.Reporting.Database/
│   ├── BookRatings.Services.Reporting.Database.sqlproj
│   ├── dbo/
│   │   ├── Tables/
│   │   │   ├── BookAnalytics.sql
│   │   │   ├── UserAnalytics.sql
│   │   │   ├── RatingTrends.sql
│   │   │   ├── Reports.sql
│   │   │   └── ReportSchedules.sql
│   │   ├── Views/
│   │   │   ├── vw_TopRatedBooks.sql
│   │   │   ├── vw_ActiveUsers.sql
│   │   │   ├── vw_RatingTrends.sql
│   │   │   └── vw_TrendingGenres.sql
│   │   ├── StoredProcedures/
│   │   │   ├── sp_GenerateBookAnalytics.sql
│   │   │   ├── sp_GenerateUserAnalytics.sql
│   │   │   ├── sp_CalculateTrends.sql
│   │   │   └── sp_ExportReport.sql
│   │   └── Indexes/
│   │       ├── IX_BookAnalytics_CreatedAt.sql
│   │       ├── IX_RatingTrends_DateBucket.sql
│   │       └── IX_Reports_CreatedAt.sql
│   ├── Pre-Deployment/Script.PreDeployment.sql
│   └── Post-Deployment/Script.PostDeployment.sql
│
└── BookRatings.Services.Reporting.Tests/
    ├── BookRatings.Services.Reporting.Tests.csproj
    ├── Unit/
    │   ├── Features/
    │   │   ├── BookAnalyticsTests.cs
    │   │   ├── TrendAnalysisTests.cs
    │   │   └── ExportTests.cs
    │   └── Services/
    │       └── AnalyticsServiceTests.cs
    ├── Integration/
    │   ├── Fixtures/
    │   │   └── ReportingContextFixture.cs
    │   └── docker-compose.yml
    └── E2E/
        └── ReportingApiE2ETests.cs
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
    <PackageReference Include="CsvHelper" Version="30.0.1" />
    <PackageReference Include="ClosedXML" Version="0.102.1" />
    <PackageReference Include="iText7" Version="7.2.5" />
    <PackageReference Include="Hangfire.AspNetCore" Version="1.8.5" />
    <PackageReference Include="Hangfire.SqlServer" Version="1.8.5" />
  </ItemGroup>
</Project>
```

## Database Schema

### Analytics Tables

```sql
CREATE TABLE [dbo].[BookAnalytics] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [BookId] INT NOT NULL,
    [Title] NVARCHAR(500),
    [Author] NVARCHAR(250),
    [TotalRatings] INT DEFAULT 0,
    [AverageRating] DECIMAL(3,2) DEFAULT 0,
    [TotalReviews] INT DEFAULT 0,
    [ViewCount] INT DEFAULT 0,
    [Popularity] DECIMAL(5,2) DEFAULT 0,
    [TrendingScore] DECIMAL(5,2) DEFAULT 0,
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE [dbo].[UserAnalytics] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [UserId] INT NOT NULL,
    [TotalRatings] INT DEFAULT 0,
    [TotalReviews] INT DEFAULT 0,
    [AverageRatingScore] DECIMAL(3,2) DEFAULT 0,
    [BooksFollowed] INT DEFAULT 0,
    [UsersFollowing] INT DEFAULT 0,
    [EngagementScore] DECIMAL(5,2) DEFAULT 0,
    [LastActivityAt] DATETIME2,
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE [dbo].[RatingTrends] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [DateBucket] DATE NOT NULL,
    [BookId] INT,
    [GenreId] INT,
    [AverageRating] DECIMAL(3,2),
    [RatingCount] INT,
    [TrendDirection] NVARCHAR(10),
    [MoMChange] DECIMAL(5,2),
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE [dbo].[Reports] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [ReportName] NVARCHAR(200) NOT NULL,
    [ReportType] NVARCHAR(50),
    [Content] VARBINARY(MAX),
    [ContentType] NVARCHAR(50),
    [CreatedBy] INT,
    [Parameters] NVARCHAR(MAX),
    [IsScheduled] BIT DEFAULT 0,
    [ScheduleFrequency] NVARCHAR(50),
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

-- Indexes
CREATE INDEX [IX_BookAnalytics_CreatedAt] ON [dbo].[BookAnalytics]([CreatedAt]);
CREATE INDEX [IX_RatingTrends_DateBucket] ON [dbo].[RatingTrends]([DateBucket]);
CREATE INDEX [IX_RatingTrends_BookId] ON [dbo].[RatingTrends]([BookId]);
CREATE INDEX [IX_Reports_CreatedAt] ON [dbo].[Reports]([CreatedAt]);
```

## Vertical Slices (Features)

### GetTopRatedBooks Slice

```csharp
public class GetTopRatedBooksRequest : IRequest<List<TopRatedBookResponse>>
{
    public int Top { get; set; } = 10;
    public int MinimumRatings { get; set; } = 10;
    public string? Language { get; set; } = "en-US";
    public DateTime? FromDate { get; set; }
}

public class GetTopRatedBooksHandler : IRequestHandler<GetTopRatedBooksRequest, List<TopRatedBookResponse>>
{
    private readonly ReportingContext _context;
    private readonly IMapper _mapper;
    private readonly ILogger<GetTopRatedBooksHandler> _logger;

    public async Task<List<TopRatedBookResponse>> Handle(
        GetTopRatedBooksRequest request,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Fetching top {Count} rated books with minimum {MinRatings} ratings",
            request.Top, request.MinimumRatings);

        var books = await _context.BookAnalytics
            .Where(b => b.TotalRatings >= request.MinimumRatings)
            .OrderByDescending(b => b.AverageRating)
            .ThenByDescending(b => b.TotalRatings)
            .Take(request.Top)
            .ToListAsync(cancellationToken);

        return _mapper.Map<List<TopRatedBookResponse>>(books);
    }
}
```

### ExportToExcel Slice

```csharp
public class ExportToExcelRequest : IRequest<ExportResponse>
{
    public string ReportType { get; set; } // "BookAnalytics", "UserAnalytics", "RatingTrends"
    public int? BookId { get; set; }
    public DateTime? FromDate { get; set; }
    public DateTime? ToDate { get; set; }
    public string Language { get; set; } = "en-US";
}

public class ExportToExcelHandler : IRequestHandler<ExportToExcelRequest, ExportResponse>
{
    private readonly ReportingContext _context;
    private readonly IExportService _exportService;
    private readonly ILogger<ExportToExcelHandler> _logger;

    public async Task<ExportResponse> Handle(
        ExportToExcelRequest request,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Exporting {ReportType} to Excel", request.ReportType);

        var data = request.ReportType switch
        {
            "BookAnalytics" => await GetBookAnalyticsData(request, cancellationToken),
            "UserAnalytics" => await GetUserAnalyticsData(request, cancellationToken),
            "RatingTrends" => await GetRatingTrendsData(request, cancellationToken),
            _ => throw new InvalidOperationException($"Unknown report type: {request.ReportType}")
        };

        var excelBytes = await _exportService.GenerateExcelAsync(data, request.ReportType);

        var report = new Report
        {
            ReportName = $"{request.ReportType}_{DateTime.UtcNow:yyyyMMdd_HHmmss}",
            ReportType = request.ReportType,
            Content = excelBytes,
            ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            Parameters = JsonConvert.SerializeObject(request)
        };

        await _context.Reports.AddAsync(report, cancellationToken);
        await _context.SaveChangesAsync(cancellationToken);

        return new ExportResponse
        {
            ReportId = report.Id,
            FileName = $"{report.ReportName}.xlsx",
            ContentType = report.ContentType,
            FileSize = excelBytes.Length
        };
    }

    private async Task<List<BookAnalyticsDto>> GetBookAnalyticsData(
        ExportToExcelRequest request,
        CancellationToken cancellationToken)
    {
        var query = _context.BookAnalytics.AsQueryable();

        if (request.FromDate.HasValue)
            query = query.Where(b => b.UpdatedAt >= request.FromDate);

        if (request.ToDate.HasValue)
            query = query.Where(b => b.UpdatedAt <= request.ToDate);

        return await query.Select(b => new BookAnalyticsDto
        {
            BookId = b.BookId,
            Title = b.Title,
            Author = b.Author,
            TotalRatings = b.TotalRatings,
            AverageRating = b.AverageRating,
            Popularity = b.Popularity
        }).ToListAsync(cancellationToken);
    }
}
```

### Event Consumer

```csharp
public class RatingSubmittedEventConsumer : IConsumer<RatingSubmittedEvent>
{
    private readonly ReportingContext _context;
    private readonly ILogger<RatingSubmittedEventConsumer> _logger;

    public async Task Consume(ConsumeContext<RatingSubmittedEvent> context)
    {
        _logger.LogInformation("Processing rating submitted event for book {BookId}",
            context.Message.BookId);

        var analytics = await _context.BookAnalytics
            .FirstOrDefaultAsync(b => b.BookId == context.Message.BookId)
            ?? new BookAnalytics { BookId = context.Message.BookId };

        analytics.TotalRatings++;
        analytics.UpdatedAt = DateTime.UtcNow;

        if (analytics.Id == 0)
            await _context.BookAnalytics.AddAsync(analytics);
        else
            _context.BookAnalytics.Update(analytics);

        await _context.SaveChangesAsync();
    }
}
```

## Scheduled Jobs (Hangfire)

### TrendCalculationJob

```csharp
public class TrendCalculationJob
{
    private readonly ReportingContext _context;
    private readonly ILogger<TrendCalculationJob> _logger;

    public async Task CalculateDailyTrends()
    {
        _logger.LogInformation("Starting daily trend calculation");

        var today = DateTime.UtcNow.Date;
        
        var bookAnalytics = await _context.BookAnalytics
            .Where(b => b.UpdatedAt.Date == today)
            .ToListAsync();

        foreach (var book in bookAnalytics)
        {
            var trend = new RatingTrend
            {
                DateBucket = today,
                BookId = book.BookId,
                AverageRating = book.AverageRating,
                RatingCount = book.TotalRatings
            };

            await _context.RatingTrends.AddAsync(trend);
        }

        await _context.SaveChangesAsync();
        _logger.LogInformation("Daily trend calculation completed");
    }
}

// In Program.cs
builder.Services.AddHangfire(config =>
    config.UseSqlServerStorage("DefaultConnection"));

builder.Services.AddHangfireServer();

// Schedule job
RecurringJob.AddOrUpdate<TrendCalculationJob>(
    "CalculateDailyTrends",
    job => job.CalculateDailyTrends(),
    "0 2 * * *" // 2 AM daily
);
```

## Global Language Support

### Multi-Language Reports

- **English (en-US)**
- **French (fr-FR)**
- **German (de-DE)**
- **Spanish (es-ES)**
- **Japanese (ja-JP)**
- **Chinese (zh-CN)**
- **Portuguese (pt-BR)**

## API Endpoints

```csharp
var group = app.MapGroup("/api/reporting")
    .WithName("Reporting")
    .WithOpenApi()
    .AllowAnonymous();

group.MapGet("/books/top-rated", GetTopRatedBooks)
    .WithName("GetTopRatedBooks")
    .Produces<List<TopRatedBookResponse>>();

group.MapGet("/books/trends", GetBookTrends)
    .WithName("GetBookTrends");

group.MapGet("/users/active", GetActiveUsers)
    .WithName("GetActiveUsers");

group.MapGet("/ratings/trends", GetRatingTrends)
    .WithName("GetRatingTrends");

group.MapPost("/export/excel", ExportToExcel)
    .WithName("ExportToExcel")
    .Accepts<ExportToExcelRequest>("application/json")
    .Produces<ExportResponse>();

group.MapPost("/export/csv", ExportToCsv)
    .WithName("ExportToCsv");

group.MapPost("/export/pdf", ExportToPdf)
    .WithName("ExportToPdf");

group.MapGet("/reports/{reportId}/download", DownloadReport)
    .WithName("DownloadReport");
```

## Configuration

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=BookRatings_Reporting;Trusted_Connection=true;"
  },
  "MassTransit": {
    "Host": "rabbitmq://localhost"
  },
  "Hangfire": {
    "Dashboard": {
      "Enabled": true,
      "Port": 5009
    }
  },
  "AllowedHosts": "*"
}
```

## Build & Test Commands

```bash
# Build Reporting Service
dotnet build Services/Reporting/

# Run tests
dotnet test Services/Reporting/BookRatings.Services.Reporting.Tests/ --filter "Category=Unit"

# Run integration tests with Podman
cd Services/Reporting/BookRatings.Services.Reporting.Tests/
docker-compose up -d
dotnet test --filter "Category=Integration"
docker-compose down

# Deploy database
msbuild Services/Reporting/BookRatings.Services.Reporting.Database.sqlproj /t:Build /p:Configuration=Release
sqlpackage /Action:Publish /SourceFile:Services/Reporting/bin/Release/BookRatings.Services.Reporting.Database.dacpac /TargetServerName:localhost /TargetDatabaseName:BookRatings_Reporting
```
