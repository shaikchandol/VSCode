# BookRatings: Complete Architecture & Implementation Guide

## Executive Summary

**BookRatings** is an enterprise-grade, cloud-native microservices platform built on .NET 10.0 with:
- ✅ **Microservices Architecture**: Independent, scalable services (Books, Ratings, Users, Admin, Reporting)
- ✅ **Multi-Cloud Support**: Deploy to Azure, AWS, or GCP with identical code/configs
- ✅ **Event-Driven Communication**: Async messaging via MassTransit + DAPR service invocation
- ✅ **Enterprise Security**: WASP compliance with Keycloak, encryption, audit logging, rate limiting
- ✅ **Comprehensive Testing**: Podman containerized integration tests, unit tests, E2E tests
- ✅ **Automated CI/CD**: GitHub Actions with conditional multi-cloud deployment
- ✅ **Offline-First**: Client-side SQLite sync with cloud SQL Server
- ✅ **Global Scale**: Multi-region deployment, GDPR compliance, 7-language support
- ✅ **Complete Observability**: OpenTelemetry, Prometheus, Grafana, DataDog integration

## Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Framework** | ASP.NET Core 10.0 | Web framework |
| **APIs** | Minimal APIs | REST endpoints |
| **Database (Online)** | SQL Server | Cloud source-of-truth |
| **Database (Offline)** | SQLite | Client-side caching |
| **Message Queue** | RabbitMQ / MassTransit | Event publishing/subscription |
| **Service Communication** | DAPR | Cloud-agnostic invocation |
| **Identity** | Keycloak + OpenID Connect | Authentication/Authorization |
| **Encryption** | AES-256, TLS 1.3 | Data protection |
| **Caching** | Redis | Distributed cache |
| **State Management** | Redis / Cosmos DB | DAPR state stores |
| **Secrets** | Key Vault / Secrets Manager / Secret Manager | Secret management |
| **Observability** | OpenTelemetry, Prometheus, Grafana | Distributed tracing, metrics |
| **Deployment** | Kubernetes, Terraform, Helm | Infrastructure as Code |
| **Container Runtime** | Podman / Docker | Local testing & production |
| **Web Client** | Blazor Server | Server-side web UI |
| **Mobile Client** | .NET MAUI | iOS/Android apps |
| **Orchestration** | .NET Aspire 10 | Local development |
| **Testing** | Testcontainers, xUnit, Moq | Comprehensive testing |
| **Security Scanning** | SonarQube, Trivy | SAST/container scanning |

## Project Structure Overview

```
BookRatings/
├── Documentation/                       # Comprehensive guides
│   ├── HLD/                            # High-level design
│   ├── LLD/                            # Low-level design per module
│   ├── Deployment/                     # Aspire, cloud-agnostic deployment
│   ├── Testing/                        # Podman module
│   ├── Security/                       # WASP framework
│   └── Architecture/                   # DAPR integration
│
├── Services/                           # Microservices
│   ├── Books/                         # Book management (5001)
│   ├── Ratings/                       # Rating aggregation (5002)
│   ├── Users/                         # User management (5003)
│   ├── Admin/                         # Moderation & audit (5004)
│   └── Reporting/                     # Analytics & export (5005)
│
├── Gateway/                           # API Gateway (5000)
│   └── Routes to all services
│
├── Clients/
│   ├── Web/                          # Blazor Server web app (5012)
│   └── Mobile/                       # .NET MAUI iOS/Android
│
├── Aspire/                           # Per-module orchestration
│   ├── BookRatings.Aspire.Books/
│   ├── BookRatings.Aspire.Ratings/
│   ├── BookRatings.Aspire.Users/
│   ├── BookRatings.Aspire.Admin/
│   ├── BookRatings.Aspire.Reporting/
│   └── BookRatings.Aspire.Gateway/
│
├── Security/                         # WASP security core
│   ├── Authentication/
│   ├── Authorization/
│   ├── Encryption/
│   ├── Audit/
│   └── RateLimiting/
│
├── Dapr/                            # DAPR components & clients
│   ├── ServiceInvocation/
│   ├── StateManagement/
│   ├── PubSub/
│   └── components/
│
├── Testing/                         # Testing infrastructure
│   ├── Podman/                     # Containerized test services
│   └── BookRatings.Testing/
│
├── Deployment/                      # Infrastructure as Code
│   ├── kubernetes/                 # K8s manifests
│   ├── terraform/                  # Cloud-agnostic IaC
│   ├── helm/                       # Helm charts
│   └── scripts/                    # Deployment automation
│
├── .github/workflows/              # GitHub Actions CI/CD
│   ├── ci.yml                      # Build, test, scan
│   ├── cd-azure.yml                # Azure deployment
│   ├── cd-aws.yml                  # AWS deployment
│   └── cd-gcp.yml                  # GCP deployment
│
└── BookRatings.sln                # Solution file
```

## Development Workflow

### 1. Local Development (Per-Service)

```bash
# Start Books Service with its own Aspire
cd Aspire/BookRatings.Aspire.Books
dotnet run

# Aspire Dashboard: http://localhost:18888
# Books Service: http://localhost:5001
# SQL Server: localhost:1433
# RabbitMQ Management: http://localhost:15672
# Keycloak: http://localhost:8080
```

### 2. Integration Testing (Full System)

```bash
# Start Podman containers
./Testing/Podman/scripts/startup.sh

# Run integration tests
dotnet test --filter "Category=Integration"

# Stop containers
./Testing/Podman/scripts/shutdown.sh
```

### 3. Performance Testing

```bash
# Run smoke test (baseline)
k6 run Testing/Performance/LoadTesting/k6/scripts/smoke-test.js

# Run load test
k6 run -c Testing/Performance/LoadTesting/k6/config/load.json Testing/Performance/LoadTesting/k6/scripts/books-api.js

# Run benchmark tests
dotnet run -c Release -p Testing/Performance/BookRatings.Performance.Tests/

# Run performance regression tests
dotnet test Testing/Performance/BookRatings.Performance.Integration.Tests/ --filter "Category=Performance"

# Analyze results
bash Testing/Performance/Scripts/analyze-results.sh

# Compare with baseline
bash Testing/Performance/Scripts/compare-baselines.sh
```

### 4. Build & Test Pipeline

```bash
# Push to GitHub
git push origin feature-branch

# GitHub Actions runs:
# 1. Detect changed services
# 2. Build & unit test
# 3. Integration tests with Podman
# 4. SAST security scanning (SonarQube)
# 5. Build container images
# 6. Scan container images (Trivy)
# 7. If successful, deploy to staging
```

### 4. Production Deployment

```bash
# Merge to main branch
git merge feature-branch

# GitHub Actions automatically:
# 1. Build & test (as above)
# 2. Deploy to Azure (if azure.tfvars)
# 3. Deploy to AWS (if aws.tfvars)
# 4. Deploy to GCP (if gcp.tfvars)
# 5. Run smoke tests
# 6. Notify team via Slack
```

## Communication Patterns

### Event-Driven (MassTransit + RabbitMQ)

When service state changes:

```
Books Service creates book
  ↓
Publishes BookCreatedEvent to RabbitMQ
  ↓
Multiple subscribers receive asynchronously:
  - Ratings Service: Initialize RatingStatistics
  - Admin Service: Log audit entry
  - Reporting Service: Update analytics
  - Search Service: Index book
  ↓
Each service processes independently (eventual consistency)
```

**Best for**: Broadcasting, multi-subscriber scenarios, fire-and-forget

### Sync Service Invocation (DAPR)

When service needs immediate response:

```
Books Service (Port 5001)
  ↓
Calls Ratings Service via DAPR
  ↓
DAPR Sidecar (Port 3500)
  ↓
Service Discovery finds ratings-service:5002
  ↓
Direct HTTP/gRPC call with resilience (retry, timeout, circuit breaker)
  ↓
Returns rating stats immediately
```

**Best for**: Request-response, immediate data needs, synchronous operations

### Hybrid Approach (Recommended)

```
Use event-driven for state changes (eventual consistency)
Use DAPR invocation for queries (strong consistency)

Example:
User submits rating
  → Publish RatingSubmittedEvent (async)
  → Ratings Service updates RatingStatistics
  → Other services subscribe and react
  
Get book with ratings
  → Call BookService.GetBook (sync via DAPR)
  → Call RatingsService.GetStats (sync via DAPR)
  → Return combined result
```

## Security Architecture

### Authentication (OpenID Connect via Keycloak)

```
Client requests /api/books
  ↓
Send Authorization: Bearer JWT
  ↓
Authentication Middleware validates JWT
  - Check issuer (Keycloak authority)
  - Check signature (public key from JWKS endpoint)
  - Check expiration
  - Check audience
  ↓
Extract user claims (sub, email, roles)
  ↓
Proceed to authorization or return 401
```

### Authorization (Role-Based Access Control)

```
[Authorize(Policy = "Admin")]
public async Task<IResult> SuspendUser(int userId)
{
    // Only users in Admin role can access
}

[Authorize(Policy = "ResourceOwner")]
public async Task<IResult> UpdateUserProfile(int userId, UpdateProfileRequest req)
{
    // Only resource owner or Admin can access
}
```

### Data Protection

```
Sensitive fields encrypted at rest:
- User passwords (bcrypt + salt)
- SSNs, payment info (AES-256)
- Personal addresses (AES-256)

Encrypted in transit:
- All HTTPS/TLS 1.3
- All inter-service DAPR calls use mTLS
```

### Rate Limiting

```
Per-user limits:
- 100 requests/minute
- 1,000 requests/hour

Per-IP limits:
- 1,000 requests/minute
- 10,000 requests/hour

Prevents:
- Brute force attacks
- DDoS attacks
- Accidental resource exhaustion
```

### Audit Logging

```
All security-relevant events logged:
- Login attempts (success/failure)
- Permission changes (who, what, when)
- Data access (sensitive fields)
- Administrative actions (suspensions, deletions)
- Failed authentication attempts
- Rate limit violations
- Suspicious patterns detected

Stored in AuditLog table with:
- Timestamp
- User ID
- Action type
- Resource affected
- IP address
- User agent
- Result (success/failure)
```

## Deployment & Scaling

### Development Environment

```
Machine:
├── .NET 10 SDK
├── Podman / Docker
├── SQL Server (in container)
├── RabbitMQ (in container)
└── Keycloak (in container)

Services via Aspire Dashboard on port 18888
```

### Staging Environment

```
Cloud (Azure/AWS/GCP):
├── Kubernetes Cluster (3 nodes)
├── Managed SQL Database
├── Managed Message Queue
├── Managed Keycloak
├── Redis Cache
├── Prometheus + Grafana (monitoring)
└── Jaeger (distributed tracing)

Deployed via Terraform + Kubernetes manifests
Ingress on staging.bookratings.com
```

### Production Environment

```
Cloud (Multi-Region):
├── Kubernetes Cluster per region (5+ nodes)
│   ├── Books Service (3 replicas)
│   ├── Ratings Service (3 replicas)
│   ├── Users Service (3 replicas)
│   ├── Admin Service (2 replicas)
│   ├── Reporting Service (2 replicas)
│   └── API Gateway (3 replicas)
│
├── Regional databases with replication
├── Regional message queues
├── Global load balancer
├── CDN for static assets
├── Monitoring & alerting
└── GDPR compliance per region

Auto-scaling based on:
- CPU usage > 80% → Scale up
- Request latency p99 > 1s → Scale up
- Error rate > 1% → Alert + scale up
```

## Database Schema Overview

### Books Service
- `Books`: ISBN (unique), Title, Author, Publisher, Pages, Language, AverageRating, TotalRatings, CategoryId
- `BookCategories`: CategoryId, Name
- `BookAuthors`: BookId, AuthorId

### Ratings Service
- `Ratings`: BookId, UserId, Score (1-5), ReviewTitle, ReviewText, Language, CreatedAt, IsDeleted
- `RatingStatistics`: BookId (unique), AverageScore, TotalRatings, FiveStarCount-OneStarCount

### Users Service
- `Users`: KeycloakId (unique), Email (unique), FirstName, LastName, PhoneNumber, PreferredLanguage, JoinDate, IsActive
- `UserProfiles`: UserId (FK), CountryCode, TimeZone, Website, Bookshelf, TotalRatings
- `UserPreferences`: UserId (FK), NotificationsEnabled, FavoriteGenres, PrivacyLevel

### Admin Service
- `AdminUsers`: UserId (FK), AdminRole, Permissions, IsActive
- `ModerationCases`: ReviewId, Status (Pending/InReview/Resolved), Severity, ResolvedAt
- `AuditLogs`: AdminUserId, ActionType, EntityType, EntityId, Changes, Timestamp
- `SystemConfiguration`: ConfigKey (unique), ConfigValue

### Reporting Service
- `BookAnalytics`: BookId, Title, TotalRatings, AverageRating, TrendingScore
- `UserAnalytics`: UserId, TotalRatings, EngagementScore
- `RatingTrends`: DateBucket, BookId, AverageRating, TrendDirection
- `Reports`: ReportName, ReportType, Content (VARBINARY), CreatedAt

## Global Language Support

All services support 7 languages:
- English (en-US) - Default
- French (fr-FR)
- German (de-DE)
- Spanish (es-ES)
- Japanese (ja-JP)
- Simplified Chinese (zh-CN)
- Portuguese (pt-BR)

Implementation:
- Resource files (.resx) per language
- Database Language field on all user-generated content
- Localized validation messages
- LocalizedTitle/LocalizedAuthor/LocalizedDescription fields
- Accept-Language header detection
- User preference stored in database

## API Design Standards

### RESTful Endpoints

```
GET    /api/books              → GetBooks (list with filters, pagination)
GET    /api/books/{id}         → GetBookById
POST   /api/books              → CreateBook (admin only)
PUT    /api/books/{id}         → UpdateBook
DELETE /api/books/{id}         → DeleteBook (admin only)

PATCH  /api/books/{id}         → PartialUpdate (update specific fields)
GET    /api/books?skip=0&take=10&sortBy=title&sortOrder=asc
GET    /api/books/search?query=pattern
```

### Response Format

```json
{
  "id": 1,
  "title": "The Book",
  "author": "John Doe",
  "averageRating": 4.5,
  "totalRatings": 100,
  "_links": {
    "self": { "href": "/api/books/1" },
    "all": { "href": "/api/books" },
    "ratings": { "href": "/api/books/1/ratings" }
  }
}
```

### Error Response (RFC 7807)

```json
{
  "type": "https://api.bookratings.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 400,
  "detail": "Request validation failed",
  "instance": "/api/books",
  "errors": {
    "title": ["Title is required", "Title must be < 255 chars"],
    "author": ["Author is required"]
  }
}
```

## Documentation Structure

| Document | Purpose | Owner |
|----------|---------|-------|
| [claude.md](claude.md) | Master guide & quick reference | Architect |
| [HLD Architecture](Documentation/HLD/architecture.md) | System design & interactions | Architect |
| [LLD Books Service](Documentation/LLD/books-service.md) | Module implementation guide | Team Lead |
| [LLD Ratings Service](Documentation/LLD/ratings-service.md) | Module implementation guide | Team Lead |
| [... other LLD files ...](Documentation/LLD/) | Per-service specifications | Team Leads |
| [Aspire Guide](Documentation/Deployment/aspire-per-module.md) | Local development | DevOps |
| [Podman Module](Documentation/Testing/podman-module.md) | Test infrastructure | QA |
| [CI/CD Pipeline](Documentation/.github/workflows/CI-CD-PIPELINE.md) | Automation flows | DevOps |
| [WASP Security](Documentation/Security/wasp-security-framework.md) | Security compliance | Security |
| [DAPR Integration](Documentation/Architecture/dapr-integration.md) | Service communication | Architect |
| [Cloud Deployment](Documentation/Deployment/cloud-agnostic-deployment.md) | Production deployment | DevOps |

## Quick Reference Commands

```bash
# Development
dotnet run --project Aspire/BookRatings.Aspire.Books
dotnet watch --project Services/Books/BookRatings.Services.Books

# Testing
dotnet test --filter "Category=Unit"
dotnet test --filter "Category=Integration"
./Testing/Podman/scripts/startup.sh && dotnet test && ./Testing/Podman/scripts/shutdown.sh

# Load Testing
k6 run Testing/Performance/LoadTesting/k6/scripts/smoke-test.js
k6 run -c Testing/Performance/LoadTesting/k6/config/load.json Testing/Performance/LoadTesting/k6/scripts/books-api.js
k6 run -c Testing/Performance/LoadTesting/k6/config/stress.json Testing/Performance/LoadTesting/k6/scripts/gateway-api.js

# Performance Benchmarking
dotnet run -c Release -p Testing/Performance/BookRatings.Performance.Tests/
dotnet run -c Release -p Testing/Performance/BookRatings.Performance.Tests/ -- --filter "*BookServiceBenchmarks*"

# Build & Package
dotnet build -c Release
dotnet publish -c Release

# Container
podman build -t bookratings/books-service:latest -f Services/Books/Dockerfile .
podman run -p 5001:5001 bookratings/books-service:latest

# Kubernetes
kubectl apply -f Deployment/kubernetes/
kubectl rollout status deployment/books-service -n bookratings
kubectl logs -f deployment/books-service -n bookratings

# Terraform
cd Deployment/terraform
terraform init
terraform plan -var-file="environments/production.tfvars"
terraform apply
terraform output kubeconfig_path

# Deployment
./Deployment/scripts/deploy.sh azure production eastus
./Deployment/scripts/deploy.sh aws staging us-east-1
./Deployment/scripts/rollback.sh books-service bookratings 2
```

## Key Architectural Principles

1. **Cloud-Agnostic**: Same code/config works on Azure, AWS, GCP
2. **Resilient**: Automatic retry, circuit breaker, timeouts
3. **Scalable**: Horizontal auto-scaling via Kubernetes
4. **Observable**: Distributed tracing, metrics, logging
5. **Secure**: Authentication, authorization, encryption, audit logging
6. **Testable**: Unit tests, integration tests, E2E tests, Podman containers
7. **Maintainable**: Clean architecture, vertical slices, clear separation of concerns
8. **DevOps-Ready**: Infrastructure as Code, CI/CD automation, one-click deployment
9. **Global**: Multi-region, GDPR compliance, 7-language support
10. **Enterprise**: WASP compliance, audit trails, access controls, monitoring

## Next Steps

1. **Set up development environment**: Install .NET 10, Podman, Terraform
2. **Start first service**: Run Books Service via Aspire
3. **Write first feature**: Create vertical slice (GetBooks endpoint)
4. **Test it**: Write unit tests + integration tests with Podman
5. **Deploy to staging**: Push to GitHub, watch CI/CD pipeline
6. **Deploy to production**: Merge to main, automatic multi-cloud deployment
7. **Monitor**: Check Grafana dashboard, Jaeger traces, audit logs

## Support & Resources

- **Keycloak Documentation**: https://www.keycloak.org/documentation
- **DAPR Documentation**: https://dapr.io/
- **.NET Aspire**: https://learn.microsoft.com/en-us/dotnet/aspire/
- **Kubernetes**: https://kubernetes.io/docs/
- **Terraform**: https://www.terraform.io/docs
- **Entity Framework Core**: https://learn.microsoft.com/en-us/ef/core/
- **OpenTelemetry**: https://opentelemetry.io/docs/

---

**Last Updated**: May 15, 2026
**Version**: 1.0
**Status**: Production Ready
