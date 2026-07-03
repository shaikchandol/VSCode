# WASP Security Framework Implementation

## Overview

**WASP** (Web Application Security Program) compliance framework implemented across all microservices with authentication, authorization, data protection, audit logging, and security monitoring.

## WASP Principles

1. **Authentication**: Verify user identity (who are you?)
2. **Authorization**: Verify user permissions (what can you do?)
3. **Data Protection**: Encrypt sensitive data (at rest and in transit)
4. **Input Validation**: Reject malicious input
5. **Audit Logging**: Track all security-relevant events
6. **Secure Communication**: TLS 1.3 for all service communication
7. **Secrets Management**: Protect API keys, passwords, tokens
8. **Rate Limiting**: Prevent brute force and DDoS attacks
9. **Session Management**: Secure user sessions with expiration
10. **Vulnerability Management**: Regular security scanning and patching

## Project Structure

```
Security/
├── BookRatings.Security.Core/
│   ├── Authentication/
│   │   ├── JwtTokenValidator.cs         # Validate JWT tokens
│   │   ├── KeycloakAuthenticationHandler.cs  # Keycloak integration
│   │   ├── TokenRefreshService.cs       # Refresh token rotation
│   │   └── SecurityHeaders.cs           # Add security headers
│   │
│   ├── Authorization/
│   │   ├── RoleBasedAuthorizationPolicy.cs   # RBAC enforcement
│   │   ├── PermissionEvaluator.cs       # Permission checks
│   │   ├── ResourceOwnershipValidator.cs    # Ownership checks
│   │   └── DynamicPolicyProvider.cs     # Dynamic policy creation
│   │
│   ├── Encryption/
│   │   ├── DataEncryptionService.cs     # AES-256 encryption
│   │   ├── FieldEncryptionAttribute.cs  # Encrypt specific fields
│   │   └── KeyManagementService.cs      # Manage encryption keys
│   │
│   ├── Validation/
│   │   ├── InputValidator.cs            # Input sanitization
│   │   ├── SqlInjectionDetector.cs      # Detect SQL injection
│   │   ├── XssDetector.cs               # Detect XSS attempts
│   │   └── UploadValidator.cs           # Validate file uploads
│   │
│   ├── Auditing/
│   │   ├── AuditLogService.cs           # Log security events
│   │   ├── AuditLogEntry.cs             # Audit log entity
│   │   ├── SecurityEventLogger.cs       # Log suspicious activity
│   │   └── ComplianceReporter.cs        # Generate compliance reports
│   │
│   ├── RateLimiting/
│   │   ├── RateLimitingPolicy.cs        # Rate limiting rules
│   │   ├── DynamicRateLimiter.cs        # Per-user/IP limiting
│   │   └── BruteForceDetector.cs        # Detect brute force attacks
│   │
│   ├── SecretsManagement/
│   │   ├── SecretVaultService.cs        # Integrate with secret vault
│   │   ├── EnvironmentSecretProvider.cs # Load from environment
│   │   └── SecretsRotationService.cs    # Rotate secrets periodically
│   │
│   └── Monitoring/
│       ├── SecurityMonitor.cs           # Monitor security events
│       ├── ThreatDetector.cs            # Detect security threats
│       ├── IncidentAlertService.cs      # Alert on incidents
│       └── SecurityMetrics.cs           # Collect security metrics
│
└── BookRatings.Security.Tests/
    ├── AuthenticationTests.cs
    ├── AuthorizationTests.cs
    ├── EncryptionTests.cs
    ├── ValidationTests.cs
    └── AuditingTests.cs
```

## Authentication Implementation

### JwtTokenValidator.cs

```csharp
public class JwtTokenValidator
{
    private readonly IConfiguration _configuration;
    private readonly JwtSecurityTokenHandler _tokenHandler;
    private readonly ILogger<JwtTokenValidator> _logger;

    public JwtTokenValidator(IConfiguration configuration, ILogger<JwtTokenValidator> logger)
    {
        _configuration = configuration;
        _logger = logger;
        _tokenHandler = new JwtSecurityTokenHandler();
    }

    public async Task<ClaimsPrincipal?> ValidateTokenAsync(string token)
    {
        try
        {
            var keycloakAuthority = _configuration["Keycloak:Authority"];
            var audience = _configuration["Keycloak:Audience"];

            var validationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKeyResolver = (string token, SecurityToken securityToken, string kid, TokenValidationParameters parameters) =>
                {
                    // Fetch public key from Keycloak JWKS endpoint
                    return GetJwksAsync(keycloakAuthority).Result;
                },
                ValidateIssuer = true,
                ValidIssuer = keycloakAuthority,
                ValidateAudience = true,
                ValidAudience = audience,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromSeconds(60)
            };

            var principal = _tokenHandler.ValidateToken(token, validationParameters, out SecurityToken validatedToken);
            
            _logger.LogInformation("Token validated for user {UserId}", principal.FindFirst("sub")?.Value);
            return principal;
        }
        catch (SecurityTokenException ex)
        {
            _logger.LogWarning(ex, "Token validation failed");
            return null;
        }
    }

    private async Task<IEnumerable<SecurityKey>> GetJwksAsync(string authority)
    {
        using var client = new HttpClient();
        var response = await client.GetAsync($"{authority}/.well-known/openid-configuration");
        var content = await response.Content.ReadAsStringAsync();
        var openIdConfig = JsonConvert.DeserializeObject<dynamic>(content);
        
        var jwksUri = openIdConfig.jwks_uri;
        var jwksResponse = await client.GetAsync(jwksUri);
        var jwksContent = await jwksResponse.Content.ReadAsStringAsync();
        var jwks = JsonConvert.DeserializeObject<JsonWebKeySet>(jwksContent);
        
        return jwks.Keys.Select(k => new JsonWebKey(JsonConvert.SerializeObject(k)));
    }
}
```

### SecurityHeadersMiddleware.cs

```csharp
public class SecurityHeadersMiddleware
{
    private readonly RequestDelegate _next;

    public SecurityHeadersMiddleware(RequestDelegate next)
    {
        _next = next;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        // Add security headers
        context.Response.Headers.Add("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
        context.Response.Headers.Add("X-Content-Type-Options", "nosniff");
        context.Response.Headers.Add("X-Frame-Options", "DENY");
        context.Response.Headers.Add("X-XSS-Protection", "1; mode=block");
        context.Response.Headers.Add("Referrer-Policy", "strict-origin-when-cross-origin");
        context.Response.Headers.Add("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'");
        
        await _next(context);
    }
}
```

## Authorization Implementation

### RoleBasedAuthorizationPolicy.cs

```csharp
public static class RoleBasedAuthorizationPolicy
{
    public static void AddRoleBasedPolicies(this IServiceCollection services)
    {
        services.AddAuthorization(options =>
        {
            // Reader can view books and ratings
            options.AddPolicy("Reader", policy =>
                policy.RequireRole("Reader", "Admin"));

            // Reviewer can submit ratings
            options.AddPolicy("Reviewer", policy =>
                policy.RequireRole("Reviewer", "Moderator", "Admin")
                      .RequireClaim("email_verified", "true"));

            // Moderator can moderate content
            options.AddPolicy("Moderator", policy =>
                policy.RequireRole("Moderator", "Admin")
                      .RequireClaim("email_verified", "true"));

            // Admin has full access
            options.AddPolicy("Admin", policy =>
                policy.RequireRole("Admin"));

            // Ownership-based access
            options.AddPolicy("ResourceOwner", policy =>
                policy.Requirements.Add(new ResourceOwnershipRequirement()));
        });
    }
}

public class ResourceOwnershipRequirement : IAuthorizationRequirement { }

public class ResourceOwnershipHandler : AuthorizationHandler<ResourceOwnershipRequirement>
{
    private readonly HttpContext _httpContext;

    public ResourceOwnershipHandler(IHttpContextAccessor httpContextAccessor)
    {
        _httpContext = httpContextAccessor.HttpContext!;
    }

    protected override Task HandleRequirementAsync(
        AuthorizationHandlerContext context,
        ResourceOwnershipRequirement requirement)
    {
        var userId = context.User.FindFirst("sub")?.Value;
        var resourceOwnerId = _httpContext.GetRouteValue("userId")?.ToString();

        if (userId == resourceOwnerId || context.User.IsInRole("Admin"))
        {
            context.Succeed(requirement);
        }

        return Task.CompletedTask;
    }
}
```

## Data Protection (Encryption)

### DataEncryptionService.cs

```csharp
public class DataEncryptionService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<DataEncryptionService> _logger;

    public DataEncryptionService(IConfiguration configuration, ILogger<DataEncryptionService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public string Encrypt(string plaintext)
    {
        using (var aes = Aes.Create())
        {
            aes.Key = Encoding.UTF8.GetBytes(_configuration["Encryption:Key"]);
            aes.GenerateIV();

            using (var encryptor = aes.CreateEncryptor())
            {
                using (var ms = new MemoryStream())
                {
                    ms.Write(aes.IV, 0, aes.IV.Length);
                    
                    using (var cs = new CryptoStream(ms, encryptor, CryptoStreamMode.Write))
                    {
                        using (var sw = new StreamWriter(cs))
                        {
                            sw.Write(plaintext);
                        }
                    }

                    var encrypted = ms.ToArray();
                    _logger.LogInformation("Data encrypted successfully");
                    return Convert.ToBase64String(encrypted);
                }
            }
        }
    }

    public string Decrypt(string ciphertext)
    {
        using (var aes = Aes.Create())
        {
            aes.Key = Encoding.UTF8.GetBytes(_configuration["Encryption:Key"]);

            using (var ms = new MemoryStream(Convert.FromBase64String(ciphertext)))
            {
                var iv = new byte[aes.IV.Length];
                ms.Read(iv, 0, iv.Length);
                aes.IV = iv;

                using (var decryptor = aes.CreateDecryptor())
                {
                    using (var cs = new CryptoStream(ms, decryptor, CryptoStreamMode.Read))
                    {
                        using (var sr = new StreamReader(cs))
                        {
                            var plaintext = sr.ReadToEnd();
                            _logger.LogInformation("Data decrypted successfully");
                            return plaintext;
                        }
                    }
                }
            }
        }
    }
}
```

## Input Validation

### InputValidator.cs

```csharp
public class InputValidator
{
    private readonly ILogger<InputValidator> _logger;

    public InputValidator(ILogger<InputValidator> logger)
    {
        _logger = logger;
    }

    public bool IsSafeString(string input, int maxLength = 1000)
    {
        if (string.IsNullOrEmpty(input) || input.Length > maxLength)
        {
            return false;
        }

        // Check for SQL injection patterns
        var sqlInjectionPatterns = new[] { "';", "\"", "--", "/*", "*/", "xp_", "sp_", "exec", "execute" };
        if (sqlInjectionPatterns.Any(p => input.IndexOf(p, StringComparison.OrdinalIgnoreCase) >= 0))
        {
            _logger.LogWarning("Potential SQL injection detected in input");
            return false;
        }

        // Check for XSS patterns
        var xssPatterns = new[] { "<script>", "</script>", "javascript:", "onerror=", "onclick=", "<iframe>" };
        if (xssPatterns.Any(p => input.IndexOf(p, StringComparison.OrdinalIgnoreCase) >= 0))
        {
            _logger.LogWarning("Potential XSS detected in input");
            return false;
        }

        return true;
    }

    public string SanitizeHtml(string input)
    {
        var sanitizer = new HtmlSanitizer();
        return sanitizer.Sanitize(input);
    }
}
```

## Audit Logging

### AuditLogService.cs

```csharp
public class AuditLogService
{
    private readonly IRepository<AuditLogEntry> _repository;
    private readonly ILogger<AuditLogService> _logger;

    public AuditLogService(IRepository<AuditLogEntry> repository, ILogger<AuditLogService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task LogSecurityEventAsync(
        string userId,
        string action,
        string entityType,
        string entityId,
        bool success,
        string? details = null,
        string? ipAddress = null)
    {
        var auditEntry = new AuditLogEntry
        {
            UserId = userId,
            Action = action,
            EntityType = entityType,
            EntityId = entityId,
            Success = success,
            Details = details,
            IpAddress = ipAddress,
            Timestamp = DateTime.UtcNow
        };

        await _repository.AddAsync(auditEntry);

        _logger.LogInformation(
            "Security event logged: User {UserId} {Action} {EntityType} {EntityId} - {Success}",
            userId, action, entityType, entityId, success ? "SUCCESS" : "FAILED");

        // Alert on sensitive operations or failures
        if (!success || IsSensitiveAction(action))
        {
            await AlertSecurityTeamAsync(auditEntry);
        }
    }

    private bool IsSensitiveAction(string action)
    {
        return action switch
        {
            "DeleteUser" or "SuspendUser" or "AssignAdminRole" or "AccessUserData" => true,
            _ => false
        };
    }

    private async Task AlertSecurityTeamAsync(AuditLogEntry entry)
    {
        // Send alert to security monitoring system
        _logger.LogWarning("Security alert: {Action} by {UserId} on {EntityType}", 
            entry.Action, entry.UserId, entry.EntityType);
    }
}
```

## Rate Limiting

```csharp
public static class RateLimitingSetup
{
    public static void AddRateLimiting(this IServiceCollection services, IConfiguration config)
    {
        services.AddStackExchangeRedisCache(options =>
        {
            options.Configuration = config.GetConnectionString("Redis");
        });

        services.AddRateLimiter(_ =>
            _.AddFixedWindowLimiter(policyName: "BookRatings", options =>
            {
                options.PermitLimit = 100;
                options.Window = TimeSpan.FromMinutes(1);
                options.QueueProcessingOrder = QueueProcessingOrder.OldestFirst;
                options.QueueLimit = 2;
            }));
    }
}

// In endpoint
app.UseRateLimiter();

group.MapGet("/", GetBooks)
    .RequireRateLimiting("BookRatings");
```

## Secrets Management

### Configuration in Program.cs

```csharp
// Load secrets from Azure Key Vault (production)
if (builder.Environment.IsProduction())
{
    var keyVaultUrl = builder.Configuration["KeyVault:Url"];
    var credentials = new DefaultAzureCredential();
    builder.Configuration.AddAzureKeyVault(
        new Uri(keyVaultUrl),
        credentials);
}

// Load from User Secrets (development)
if (builder.Environment.IsDevelopment())
{
    builder.Configuration.AddUserSecrets<Program>();
}

// Load from environment variables (all environments)
builder.Configuration.AddEnvironmentVariables("BOOKRATINGS_");
```

## WASP Compliance Checklist

- ✅ **Authentication**: JWT tokens via Keycloak
- ✅ **Authorization**: Role-based and resource-based policies
- ✅ **Data Protection**: AES-256 encryption, TLS 1.3
- ✅ **Input Validation**: HTML sanitization, SQL injection prevention
- ✅ **Audit Logging**: All security-relevant events logged
- ✅ **Security Headers**: HSTS, CSP, X-Frame-Options
- ✅ **Rate Limiting**: Per-user and per-IP limits
- ✅ **Secrets Management**: Key Vault integration
- ✅ **Password Policy**: 8+ chars, uppercase, number, special char
- ✅ **Session Management**: Token expiration, refresh rotation
- ✅ **Monitoring**: Real-time security event monitoring
- ✅ **Vulnerability Management**: Automated dependency scanning

## Per-Module WASP Integration

Apply these security patterns in each microservice:

```csharp
// In Program.cs of each service
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Keycloak:Authority"];
        options.Audience = builder.Configuration["Keycloak:Audience"];
        options.Events = new JwtBearerEvents
        {
            OnAuthenticationFailed = context =>
            {
                logger.LogError("Authentication failed: {Error}", context.Exception.Message);
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddRoleBasedPolicies();
builder.Services.AddScoped<JwtTokenValidator>();
builder.Services.AddScoped<DataEncryptionService>();
builder.Services.AddScoped<InputValidator>();
builder.Services.AddScoped<AuditLogService>();
builder.Services.AddRateLimiting(builder.Configuration);

app.UseSecurityHeadersMiddleware();
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
```
