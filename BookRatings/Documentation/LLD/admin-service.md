# Admin Service - Low-Level Design

## Overview

The **Admin Service** provides administrative capabilities including user management, content moderation, system configuration, and audit logging.

## Project Structure

### C# Projects (.csproj)

```
Services/Admin/
├── BookRatings.Services.Admin/
│   ├── BookRatings.Services.Admin.csproj
│   ├── Program.cs
│   ├── Core/
│   │   └── Domain/
│   │       ├── AdminAction.cs
│   │       ├── ModerationCase.cs
│   │       ├── AuditLog.cs
│   │       └── AdminException.cs
│   ├── Features/
│   │   ├── UserManagement/
│   │   │   ├── SuspendUser/
│   │   │   ├── ActivateUser/
│   │   │   ├── DeleteUserAccount/
│   │   │   └── AssignRole/
│   │   ├── ContentModeration/
│   │   │   ├── FlagReview/
│   │   │   ├── ModerateReview/
│   │   │   ├── RemoveInappropriateContent/
│   │   │   └── GetModerationQueue/
│   │   ├── SystemConfiguration/
│   │   │   ├── UpdateSettings/
│   │   │   ├── GetSystemStatus/
│   │   │   └── ConfigureLanguages/
│   │   └── AuditLog/
│   │       ├── GetAuditLogs/
│   │       └── ExportAuditReport/
│   ├── Data/
│   │   ├── AdminContext.cs
│   │   ├── Configurations/
│   │   │   └── AuditLogConfiguration.cs
│   │   └── Migrations/
│   ├── Services/
│   │   ├── ModerationService.cs
│   │   ├── AuditLogService.cs
│   │   └── SystemConfigService.cs
│   ├── EventConsumers/
│   │   ├── RatingSubmittedEventConsumer.cs
│   │   └── UserRegisteredEventConsumer.cs
│   ├── Endpoints/
│   │   ├── AdminEndpoints.cs
│   │   └── ModerationEndpoints.cs
│   ├── appsettings.json
│   └── appsettings.Production.json
│
├── BookRatings.Services.Admin.Database/
│   ├── BookRatings.Services.Admin.Database.sqlproj
│   ├── dbo/
│   │   ├── Tables/
│   │   │   ├── AdminUsers.sql
│   │   │   ├── ModerationCases.sql
│   │   │   ├── AuditLogs.sql
│   │   │   └── SystemConfiguration.sql
│   │   ├── Views/
│   │   │   └── vw_PendingModerations.sql
│   │   └── Indexes/
│   │       ├── IX_ModerationCases_Status.sql
│   │       └── IX_AuditLogs_CreatedAt.sql
│   ├── Pre-Deployment/Script.PreDeployment.sql
│   └── Post-Deployment/Script.PostDeployment.sql
│
└── BookRatings.Services.Admin.Tests/
    ├── BookRatings.Services.Admin.Tests.csproj
    ├── Unit/
    │   └── Features/
    │       ├── ModerationTests.cs
    │       └── UserManagementTests.cs
    ├── Integration/
    │   ├── Fixtures/
    │   │   └── AdminContextFixture.cs
    │   └── docker-compose.yml
    └── E2E/
        └── AdminApiE2ETests.cs
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
    <PackageReference Include="FluentValidation" Version="11.8.0" />
    <PackageReference Include="CsvHelper" Version="30.0.1" />
  </ItemGroup>
</Project>
```

## Database Schema

### Admin Tables

```sql
CREATE TABLE [dbo].[AdminUsers] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [UserId] INT NOT NULL,
    [AdminRole] NVARCHAR(50) NOT NULL,
    [Permissions] NVARCHAR(MAX),
    [ApprovedAt] DATETIME2,
    [ApprovedBy] INT,
    [IsActive] BIT DEFAULT 1,
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE [dbo].[ModerationCases] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [ReviewId] INT NOT NULL,
    [ReporterUserId] INT,
    [ReportReason] NVARCHAR(500),
    [Status] NVARCHAR(20), -- Pending, InReview, Resolved, Dismissed
    [Severity] NVARCHAR(20), -- Low, Medium, High, Critical
    [AssignedToAdminId] INT,
    [ModerationAction] NVARCHAR(500),
    [Resolution] NVARCHAR(MAX),
    [ResolvedAt] DATETIME2,
    [ResolvedBy] INT,
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE [dbo].[AuditLogs] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [AdminUserId] INT NOT NULL,
    [ActionType] NVARCHAR(100),
    [EntityType] NVARCHAR(100),
    [EntityId] INT,
    [Changes] NVARCHAR(MAX),
    [Reason] NVARCHAR(500),
    [IpAddress] NVARCHAR(50),
    [UserAgent] NVARCHAR(500),
    [IsSuccess] BIT DEFAULT 1,
    [ErrorMessage] NVARCHAR(MAX),
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE [dbo].[SystemConfiguration] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [ConfigKey] NVARCHAR(100) UNIQUE NOT NULL,
    [ConfigValue] NVARCHAR(MAX),
    [ConfigType] NVARCHAR(50),
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [UpdatedBy] INT
);

-- Indexes
CREATE INDEX [IX_ModerationCases_Status] ON [dbo].[ModerationCases]([Status]);
CREATE INDEX [IX_ModerationCases_AssignedToAdminId] ON [dbo].[ModerationCases]([AssignedToAdminId]);
CREATE INDEX [IX_AuditLogs_CreatedAt] ON [dbo].[AuditLogs]([CreatedAt]);
CREATE INDEX [IX_AuditLogs_ActionType] ON [dbo].[AuditLogs]([ActionType]);
```

## Vertical Slices (Features)

### ModerateReview Slice

```csharp
public class ModerateReviewRequest : IRequest<ModerateReviewResponse>
{
    public int ModerationCaseId { get; set; }
    public string Decision { get; set; } // Approve, Reject, RemoveContent
    public string? Reason { get; set; }
    public int AdminId { get; set; }
}

public class ModerateReviewHandler : IRequestHandler<ModerateReviewRequest, ModerateReviewResponse>
{
    private readonly AdminContext _context;
    private readonly IAuditLogService _auditLogService;
    private readonly IPublishEndpoint _publishEndpoint;
    private readonly ILogger<ModerateReviewHandler> _logger;

    public async Task<ModerateReviewResponse> Handle(
        ModerateReviewRequest request,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Moderating case {CaseId} with decision {Decision}", 
            request.ModerationCaseId, request.Decision);

        var moderationCase = await _context.ModerationCases
            .FirstOrDefaultAsync(c => c.Id == request.ModerationCaseId, cancellationToken)
            ?? throw new ModerationCaseNotFoundException();

        moderationCase.Status = "Resolved";
        moderationCase.ModerationAction = request.Decision;
        moderationCase.Resolution = request.Reason;
        moderationCase.ResolvedAt = DateTime.UtcNow;
        moderationCase.ResolvedBy = request.AdminId;

        _context.ModerationCases.Update(moderationCase);

        // Log audit trail
        await _auditLogService.LogActionAsync(new AuditLogEntry
        {
            AdminUserId = request.AdminId,
            ActionType = "MODERATE_REVIEW",
            EntityType = "ModerationCase",
            EntityId = moderationCase.Id,
            Changes = $"Decision: {request.Decision}",
            Reason = request.Reason
        });

        await _context.SaveChangesAsync(cancellationToken);

        // Publish event
        await _publishEndpoint.Publish(new ReviewModerationEvent
        {
            ModerationCaseId = moderationCase.Id,
            ReviewId = moderationCase.ReviewId,
            Decision = request.Decision,
            ModerationAction = moderationCase.ModerationAction,
            ResolvedAt = moderationCase.ResolvedAt.Value
        }, cancellationToken);

        return new ModerateReviewResponse { CaseId = moderationCase.Id };
    }
}
```

### AuditLog Service

```csharp
public class AuditLogService
{
    private readonly AdminContext _context;
    private readonly ILogger<AuditLogService> _logger;

    public async Task LogActionAsync(AuditLogEntry entry)
    {
        var auditLog = new AuditLog
        {
            AdminUserId = entry.AdminUserId,
            ActionType = entry.ActionType,
            EntityType = entry.EntityType,
            EntityId = entry.EntityId,
            Changes = entry.Changes,
            Reason = entry.Reason,
            CreatedAt = DateTime.UtcNow
        };

        await _context.AuditLogs.AddAsync(auditLog);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Audit log created: {ActionType} on {EntityType} {EntityId}",
            entry.ActionType, entry.EntityType, entry.EntityId);
    }

    public async Task<List<AuditLog>> GetAuditLogsAsync(
        string? actionType = null,
        DateTime? fromDate = null,
        DateTime? toDate = null,
        int skip = 0,
        int take = 50)
    {
        var query = _context.AuditLogs.AsQueryable();

        if (!string.IsNullOrEmpty(actionType))
            query = query.Where(l => l.ActionType == actionType);

        if (fromDate.HasValue)
            query = query.Where(l => l.CreatedAt >= fromDate);

        if (toDate.HasValue)
            query = query.Where(l => l.CreatedAt <= toDate);

        return await query
            .OrderByDescending(l => l.CreatedAt)
            .Skip(skip)
            .Take(take)
            .ToListAsync();
    }
}
```

## Events Published

- **ReviewModerationEvent** - Review moderation decision made
- **UserSuspendedEvent** - User account suspended
- **UserActivatedEvent** - User account reactivated
- **ContentRemovedEvent** - Inappropriate content removed
- **AuditLogCreatedEvent** - Admin action logged

## Events Consumed

- **RatingSubmittedEvent** - Flag inappropriate ratings for moderation
- **ReviewFlaggedEvent** - Add to moderation queue

## Global Language Support

### Moderation Interface Languages

- **English (en-US)**
- **French (fr-FR)**
- **German (de-DE)**
- **Spanish (es-ES)**
- **Japanese (ja-JP)**
- **Chinese (zh-CN)**
- **Portuguese (pt-BR)**

## API Endpoints (RBAC Protected)

```csharp
var group = app.MapGroup("/api/admin")
    .WithName("Admin")
    .WithOpenApi()
    .RequireAuthorization(policy => policy.RequireRole("Admin"));

group.MapGet("/moderation/queue", GetModerationQueue)
    .WithName("GetModerationQueue");

group.MapPost("/moderation/{caseId}/resolve", ModerateReview)
    .WithName("ModerateReview");

group.MapDelete("/users/{userId}/suspend", SuspendUser)
    .WithName("SuspendUser");

group.MapPost("/users/{userId}/activate", ActivateUser)
    .WithName("ActivateUser");

group.MapGet("/audit-logs", GetAuditLogs)
    .WithName("GetAuditLogs");

group.MapGet("/system/config", GetSystemConfiguration)
    .WithName("GetSystemConfiguration");

group.MapPut("/system/config", UpdateSystemConfiguration)
    .WithName("UpdateSystemConfiguration")
    .RequireAuthorization(policy => policy.RequireRole("SuperAdmin"));
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
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=BookRatings_Admin;Trusted_Connection=true;"
  },
  "MassTransit": {
    "Host": "rabbitmq://localhost"
  },
  "AllowedHosts": "*"
}
```

## Build & Test Commands

```bash
# Build Admin Service
dotnet build Services/Admin/

# Run tests with Podman
cd Services/Admin/BookRatings.Services.Admin.Tests/
docker-compose up -d
dotnet test
docker-compose down

# Deploy database
msbuild Services/Admin/BookRatings.Services.Admin.Database.sqlproj /t:Build /p:Configuration=Release
sqlpackage /Action:Publish /SourceFile:Services/Admin/bin/Release/BookRatings.Services.Admin.Database.dacpac /TargetServerName:localhost /TargetDatabaseName:BookRatings_Admin
```
