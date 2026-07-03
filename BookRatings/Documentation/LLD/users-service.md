# Users Service - Low-Level Design

## Overview

The **Users Service** manages user accounts, profiles, authentication state, and user preferences. It integrates with Keycloak for identity management and tracks user activity.

## Project Structure

### C# Projects (.csproj)

```
Services/Users/
├── BookRatings.Services.Users/
│   ├── BookRatings.Services.Users.csproj
│   ├── Program.cs
│   ├── Core/
│   │   └── Domain/
│   │       ├── User.cs                  # User aggregate root
│   │       ├── UserProfile.cs
│   │       ├── UserPreferences.cs
│   │       ├── UserException.cs
│   │       └── ValueObjects/
│   │           ├── Email.cs
│   │           └── PhoneNumber.cs
│   ├── Features/
│   │   ├── RegisterUser/
│   │   │   ├── Request.cs
│   │   │   ├── Response.cs
│   │   │   ├── Handler.cs
│   │   │   ├── Validator.cs
│   │   │   └── RegisterUserEndpoint.cs
│   │   ├── GetUser/
│   │   ├── UpdateProfile/
│   │   ├── UpdatePreferences/
│   │   ├── DeleteUser/
│   │   └── GetUserStatistics/
│   ├── Data/
│   │   ├── UsersContext.cs
│   │   ├── Configurations/
│   │   │   └── UserConfiguration.cs
│   │   └── Migrations/
│   ├── Services/
│   │   ├── UserService.cs
│   │   ├── ProfileService.cs
│   │   └── KeycloakService.cs           # Keycloak integration
│   ├── EventConsumers/
│   │   └── UserActivityEventConsumer.cs
│   ├── Endpoints/
│   │   └── UsersEndpoints.cs
│   ├── appsettings.json
│   └── appsettings.Production.json
│
├── BookRatings.Services.Users.Database/
│   ├── BookRatings.Services.Users.Database.sqlproj
│   ├── dbo/
│   │   ├── Tables/
│   │   │   ├── Users.sql
│   │   │   ├── UserProfiles.sql
│   │   │   ├── UserPreferences.sql
│   │   │   └── UserActivityLog.sql
│   │   ├── Views/
│   │   │   └── vw_ActiveUsers.sql
│   │   ├── StoredProcedures/
│   │   │   ├── sp_GetUserProfile.sql
│   │   │   └── sp_LogUserActivity.sql
│   │   └── Indexes/
│   │       ├── IX_Users_Email.sql
│   │       └── IX_Users_KeycloakId.sql
│   ├── Pre-Deployment/Script.PreDeployment.sql
│   ├── Post-Deployment/Script.PostDeployment.sql
│   └── Migrations/
│
└── BookRatings.Services.Users.Tests/
    ├── BookRatings.Services.Users.Tests.csproj
    ├── Unit/
    │   ├── Features/
    │   │   ├── RegisterUserTests.cs
    │   │   ├── UpdateProfileTests.cs
    │   │   └── UserValidationTests.cs
    │   └── Services/
    │       └── KeycloakServiceTests.cs
    ├── Integration/
    │   ├── Fixtures/
    │   │   ├── UsersContextFixture.cs
    │   │   └── KeycloakMockFixture.cs
    │   ├── Features/
    │   │   └── RegisterUserIntegrationTests.cs
    │   └── docker-compose.yml
    └── E2E/
        └── UsersApiE2ETests.cs
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
    <PackageReference Include="Keycloak.Net" Version="3.12.0" />
    <PackageReference Include="FluentValidation" Version="11.8.0" />
    <PackageReference Include="AutoMapper.Extensions.Microsoft.DependencyInjection" Version="12.0.1" />
    <PackageReference Include="System.Net.Http" Version="4.3.4" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\Shared\BookRatings.Shared.Contracts\BookRatings.Shared.Contracts.csproj" />
  </ItemGroup>
</Project>
```

## Database Schema

### Users Table

```sql
CREATE TABLE [dbo].[Users] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [KeycloakId] NVARCHAR(MAX) UNIQUE NOT NULL,
    [Email] NVARCHAR(256) UNIQUE NOT NULL,
    [FirstName] NVARCHAR(100),
    [LastName] NVARCHAR(100),
    [PhoneNumber] NVARCHAR(20),
    [ProfileImageUrl] NVARCHAR(500),
    [Bio] NVARCHAR(500),
    [JoinDate] DATETIME2 DEFAULT GETUTCDATE(),
    [LastLoginDate] DATETIME2,
    [IsActive] BIT DEFAULT 1,
    [PreferredLanguage] VARCHAR(10) DEFAULT 'en-US',
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE(),
    [IsDeleted] BIT DEFAULT 0
);

CREATE TABLE [dbo].[UserProfiles] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [UserId] INT FOREIGN KEY REFERENCES [dbo].[Users]([Id]),
    [CountryCode] CHAR(2),
    [TimeZone] NVARCHAR(50),
    [Website] NVARCHAR(500),
    [SocialMediaLinks] NVARCHAR(MAX),
    [BookshelfUrl] NVARCHAR(500),
    [TotalRatings] INT DEFAULT 0,
    [FollowersCount] INT DEFAULT 0,
    [FollowingCount] INT DEFAULT 0,
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE [dbo].[UserPreferences] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [UserId] INT FOREIGN KEY REFERENCES [dbo].[Users]([Id]),
    [NotificationsEnabled] BIT DEFAULT 1,
    [EmailNotifications] BIT DEFAULT 1,
    [PushNotifications] BIT DEFAULT 1,
    [RatingReminders] BIT DEFAULT 1,
    [NewReleaseNotifications] BIT DEFAULT 1,
    [FavoriteGenres] NVARCHAR(MAX),
    [PrivacyLevel] NVARCHAR(20),
    [AllowRecommendations] BIT DEFAULT 1,
    [UpdatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

CREATE TABLE [dbo].[UserActivityLog] (
    [Id] INT PRIMARY KEY IDENTITY(1,1),
    [UserId] INT FOREIGN KEY REFERENCES [dbo].[Users]([Id]),
    [ActivityType] NVARCHAR(50),
    [ActivityData] NVARCHAR(MAX),
    [IpAddress] NVARCHAR(50),
    [UserAgent] NVARCHAR(500),
    [CreatedAt] DATETIME2 DEFAULT GETUTCDATE()
);

-- Indexes
CREATE INDEX [IX_Users_Email] ON [dbo].[Users]([Email]);
CREATE INDEX [IX_Users_KeycloakId] ON [dbo].[Users]([KeycloakId]);
CREATE INDEX [IX_UserActivityLog_UserId] ON [dbo].[UserActivityLog]([UserId]);
CREATE INDEX [IX_UserActivityLog_CreatedAt] ON [dbo].[UserActivityLog]([CreatedAt]);
```

## Vertical Slices (Features)

### RegisterUser Slice

```csharp
public class RegisterUserRequest : IRequest<RegisterUserResponse>
{
    public string Email { get; set; }
    public string FirstName { get; set; }
    public string LastName { get; set; }
    public string Password { get; set; }
    public string? PhoneNumber { get; set; }
    public string PreferredLanguage { get; set; } = "en-US";
    public string? CountryCode { get; set; }
}

public class RegisterUserValidator : AbstractValidator<RegisterUserRequest>
{
    public RegisterUserValidator(IStringLocalizer<RegisterUserValidator> localizer)
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress()
            .WithMessage(localizer["Email_Invalid"]);

        RuleFor(x => x.FirstName)
            .NotEmpty()
            .WithMessage(localizer["FirstName_Required"]);

        RuleFor(x => x.Password)
            .NotEmpty()
            .MinimumLength(8)
            .Matches(@"[A-Z]")
            .Matches(@"[0-9]")
            .Matches(@"[!@#$%^&*]")
            .WithMessage(localizer["Password_Complexity"]);
    }
}

public class RegisterUserHandler : IRequestHandler<RegisterUserRequest, RegisterUserResponse>
{
    private readonly UsersContext _context;
    private readonly IKeycloakClient _keycloakClient;
    private readonly IPublishEndpoint _publishEndpoint;
    private readonly IMapper _mapper;
    private readonly ILogger<RegisterUserHandler> _logger;

    public async Task<RegisterUserResponse> Handle(
        RegisterUserRequest request,
        CancellationToken cancellationToken)
    {
        _logger.LogInformation("Registering user: {Email}", request.Email);

        // Create Keycloak user first
        var keycloakUser = new UserRepresentation
        {
            Username = request.Email,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            Enabled = true,
            Credentials = new List<CredentialRepresentation>
            {
                new CredentialRepresentation
                {
                    Type = "password",
                    Value = request.Password,
                    Temporary = false
                }
            }
        };

        var keycloakId = await _keycloakClient.CreateUserAsync(keycloakUser);

        // Create local user record
        var user = new User
        {
            KeycloakId = keycloakId,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            PhoneNumber = request.PhoneNumber,
            PreferredLanguage = request.PreferredLanguage,
            IsActive = true
        };

        await _context.Users.AddAsync(user, cancellationToken);

        var profile = new UserProfile
        {
            User = user,
            CountryCode = request.CountryCode
        };

        await _context.UserProfiles.AddAsync(profile, cancellationToken);

        var preferences = new UserPreferences
        {
            User = user,
            NotificationsEnabled = true,
            EmailNotifications = true,
            PreferredLanguage = request.PreferredLanguage
        };

        await _context.UserPreferences.AddAsync(preferences, cancellationToken);

        await _context.SaveChangesAsync(cancellationToken);

        // Publish event
        await _publishEndpoint.Publish(new UserRegisteredEvent
        {
            UserId = user.Id,
            KeycloakId = user.KeycloakId,
            Email = user.Email,
            FirstName = user.FirstName,
            LastName = user.LastName,
            PreferredLanguage = user.PreferredLanguage,
            CreatedAt = DateTime.UtcNow
        }, cancellationToken);

        _logger.LogInformation("User registered successfully: {UserId}", user.Id);

        return _mapper.Map<RegisterUserResponse>(user);
    }
}
```

## Keycloak Integration

### KeycloakService

```csharp
public class KeycloakService
{
    private readonly IKeycloakClient _keycloakClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<KeycloakService> _logger;

    public async Task<string> CreateUserAsync(CreateUserRequest request)
    {
        var user = new UserRepresentation
        {
            Username = request.Email,
            Email = request.Email,
            FirstName = request.FirstName,
            LastName = request.LastName,
            Enabled = true,
            Credentials = new List<CredentialRepresentation>
            {
                new CredentialRepresentation
                {
                    Type = "password",
                    Value = request.Password,
                    Temporary = false
                }
            }
        };

        var userId = await _keycloakClient.CreateUserAsync(user);
        _logger.LogInformation("Keycloak user created: {UserId}", userId);

        return userId;
    }

    public async Task AssignRoleAsync(string userId, string roleName)
    {
        var role = await _keycloakClient.GetRoleByNameAsync(roleName);
        await _keycloakClient.AssignRoleToUserAsync(userId, role);
    }

    public async Task UpdateUserAsync(string userId, UpdateUserRequest request)
    {
        var user = new UserRepresentation
        {
            FirstName = request.FirstName,
            LastName = request.LastName,
            Email = request.Email
        };

        await _keycloakClient.UpdateUserAsync(userId, user);
    }

    public async Task DeleteUserAsync(string userId)
    {
        await _keycloakClient.DeleteUserAsync(userId);
        _logger.LogInformation("Keycloak user deleted: {UserId}", userId);
    }
}
```

## Events Published

- **UserRegisteredEvent** - New user account created
- **UserUpdatedEvent** - User profile modified
- **UserDeletedEvent** - User account removed
- **UserActivityLoggedEvent** - User action tracked

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
      - "1435:1433"
    healthcheck:
      test: ["CMD", "/opt/mssql-tools/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", "YourPassword123!", "-Q", "SELECT 1"]
      interval: 10s
      timeout: 3s
      retries: 5

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    environment:
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
      KC_DB: dev-mem
    ports:
      - "8080:8080"
    command: start-dev
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/auth"]
      interval: 10s
      timeout: 5s
      retries: 5

  rabbitmq:
    image: rabbitmq:3.12-management
    ports:
      - "5674:5672"
      - "15674:15672"
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

## Global Language Support

### Supported Languages

- **English (en-US)** - Default
- **French (fr-FR)**
- **German (de-DE)**
- **Spanish (es-ES)**
- **Japanese (ja-JP)**
- **Chinese (zh-CN)**
- **Portuguese (pt-BR)**

### User Language Preferences

```csharp
public class UpdatePreferencesRequest : IRequest<UpdatePreferencesResponse>
{
    public string PreferredLanguage { get; set; } = "en-US";
    public bool NotificationsEnabled { get; set; }
    public bool EmailNotifications { get; set; }
    public List<string> FavoriteGenres { get; set; } = new();
}
```

## API Endpoints

```csharp
var group = app.MapGroup("/api/users")
    .WithName("Users")
    .WithOpenApi();

group.MapPost("/register", RegisterUser)
    .WithName("RegisterUser")
    .AllowAnonymous()
    .Accepts<RegisterUserRequest>("application/json")
    .Produces<RegisterUserResponse>(StatusCodes.Status201Created);

group.MapGet("/{id}", GetUser)
    .WithName("GetUser")
    .RequireAuthorization()
    .Produces<GetUserResponse>();

group.MapPut("/{id}/profile", UpdateProfile)
    .WithName("UpdateProfile")
    .RequireAuthorization()
    .Produces(StatusCodes.Status204NoContent);

group.MapPut("/{id}/preferences", UpdatePreferences)
    .WithName("UpdatePreferences")
    .RequireAuthorization()
    .Produces(StatusCodes.Status204NoContent);

group.MapDelete("/{id}", DeleteUser)
    .WithName("DeleteUser")
    .RequireAuthorization()
    .Produces(StatusCodes.Status204NoContent);
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
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=BookRatings_Users;Trusted_Connection=true;"
  },
  "Keycloak": {
    "Authority": "http://localhost:8080/auth/realms/bookratings",
    "ClientId": "users-service",
    "ClientSecret": "${Keycloak:ClientSecret}",
    "AdminUrl": "http://localhost:8080/auth/admin/realms/bookratings",
    "AdminUsername": "admin",
    "AdminPassword": "${Keycloak:AdminPassword}"
  },
  "MassTransit": {
    "Host": "rabbitmq://localhost"
  },
  "AllowedHosts": "*"
}
```

## Build & Test Commands

```bash
# Build Users Service
dotnet build Services/Users/

# Run unit tests
dotnet test Services/Users/BookRatings.Services.Users.Tests/ --filter "Category=Unit"

# Run integration tests with Podman
cd Services/Users/BookRatings.Services.Users.Tests/
docker-compose up -d
dotnet test --filter "Category=Integration"
docker-compose down

# Deploy database
msbuild Services/Users/BookRatings.Services.Users.Database.sqlproj /t:Build /p:Configuration=Release
sqlpackage /Action:Publish /SourceFile:Services/Users/bin/Release/BookRatings.Services.Users.Database.dacpac /TargetServerName:localhost /TargetDatabaseName:BookRatings_Users
```
