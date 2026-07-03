# BookRatings: TOGAF Enterprise Architecture Framework

**Integrated Architecture**: TOGAF + DDD + Clean Architecture + CQRS + Event-Driven + Zero Trust + CNCF Cloud Native + Observability

---

## Executive Summary

BookRatings is an **enterprise-grade, TOGAF-aligned microservices platform** that seamlessly integrates:

- **TOGAF ADM**: Governance, business capabilities, and architecture domains
- **Domain-Driven Design (DDD)**: Bounded contexts, aggregates, event sourcing
- **Clean Architecture**: Layered separation of concerns
- **CQRS**: Command-Query Responsibility Segregation with MediatR
- **Event-Driven Architecture**: Asynchronous, loosely-coupled services
- **Zero Trust Security**: Every access request authenticated and authorized
- **CNCF Cloud Native**: Kubernetes, container-native patterns
- **Observability**: OpenTelemetry, distributed tracing, metrics, logging

This document maps enterprise governance to cloud-native implementation.

---

## Part 1: TOGAF ADM (Architecture Development Method)

### Phase A: Architecture Vision

**Goal**: Define strategic business objectives and architecture goals

#### Business Context

```
BookRatings Business Capabilities

├── Catalog Management
│   ├── Book Management (Create, Read, Update, Delete)
│   ├── Category & Tags
│   └── Metadata Management
│
├── Rating & Review
│   ├── Submit Ratings
│   ├── Write Reviews
│   ├── Moderation Queue
│   └── Analytics
│
├── User Management
│   ├── User Registration
│   ├── Profile Management
│   ├── Preferences & Settings
│   └── Activity Tracking
│
├── Reporting & Analytics
│   ├── Book Analytics
│   ├── Trend Analysis
│   ├── User Analytics
│   └── Report Export (CSV, Excel, PDF)
│
└── Administration
    ├── Content Moderation
    ├── User Management
    ├── System Configuration
    └── Audit Logging
```

#### Stakeholder Analysis

| Stakeholder | Concerns | Requirements |
|---|---|---|
| **Executive** | ROI, time-to-market, scalability | TOGAF governance, cost optimization |
| **CIO** | Security, compliance, integration | Zero Trust, WASP compliance, observability |
| **Architect** | Design patterns, maintainability | TOGAF, DDD, Clean Architecture |
| **Developer** | Development velocity, testability | Clean code, CQRS, vertical slices |
| **Operations** | Reliability, monitoring, deployment | CNCF, Kubernetes, health checks |
| **Security** | Data protection, access control | Encryption, audit logs, rate limiting |

#### Architecture Vision

```
Principle: "Cloud-Native, Event-Driven, Zero-Trust Enterprise Platform"

1. Cloud-Agnostic: Deploy to Azure, AWS, GCP identically
2. Microservices: Independent, scalable services per bounded context
3. Offline-First: Works offline, syncs when connected
4. Secure-by-Default: Zero Trust architecture throughout
5. Observable: Complete visibility into system behavior
6. Compliant: WASP security, GDPR, audit-ready
```

### Phase B: Business Architecture

**Goal**: Define business processes, capabilities, and value streams

#### Business Capabilities Map

```
BookRatings Business Capability Model

Level 1: Strategic Capabilities
├── Book Discovery & Management
├── User Engagement & Feedback
├── Content Moderation & Safety
└── Analytics & Insights

Level 2: Detailed Capabilities
├── Book Discovery & Management
│   ├── Catalog Management
│   ├── Book Search & Filtering
│   ├── Recommendation Engine
│   └── Import/Export
│
├── User Engagement & Feedback
│   ├── User Registration & Auth
│   ├── Rating Submission
│   ├── Review Writing
│   └── Notification Management
│
├── Content Moderation & Safety
│   ├── Review Moderation
│   ├── User Behavior Monitoring
│   ├── Complaint Handling
│   └── Audit Logging
│
└── Analytics & Insights
    ├── Book Performance Analytics
    ├── User Behavior Analytics
    ├── Trend Analysis
    └── Report Generation
```

#### Value Stream Mapping

```
User Rates a Book (Value Stream)

1. User Discovery Phase (Time: 2 min)
   ├── Browse catalog
   ├── View book details
   └── Check existing ratings

2. Rating Submission Phase (Time: 1 min)
   ├── Submit rating (1-5 stars)
   ├── Write review text
   └── Add tags/categories

3. Processing Phase (Time: <1 sec)
   ├── Validate input
   ├── Store rating
   ├── Update statistics
   └── Publish event

4. Distribution Phase (Time: <5 sec)
   ├── Notify followers
   ├── Update analytics
   ├── Trigger moderation (if needed)
   └── Update search index

Total Value Delivery Time: ~3 min
Non-Value-Add Wait: ~0.1 sec (system processing)
```

#### Organization Structure & Responsibilities

```
Enterprise Architecture
├── TOGAF Board
│   └── Governance & Approval
│
├── Architecture Teams
│   ├── Business Architects
│   │   └── Capability Modeling, Value Streams
│   ├── Application Architects
│   │   └── Service Design, Integration
│   ├── Data Architects
│   │   └── Database, ETL, Analytics
│   └── Infrastructure Architects
│       └── Kubernetes, Cloud, Networking
│
└── Project Teams
    ├── Books Service Team
    ├── Ratings Service Team
    ├── Users Service Team
    ├── Admin Service Team
    └── Reporting Service Team
```

### Phase C: Information Systems Architecture

**Goal**: Define application and data architecture

#### Application Architecture (with TOGAF/DDD Mapping)

```
TOGAF Layer                  DDD Concept              Clean Architecture
─────────────────────────────────────────────────────────────────────────
Business Layer               Bounded Context          Application Layer
                            ├── Books Context         │ Features, Handlers
                            ├── Ratings Context       │ Use Cases
                            ├── Users Context         │ Validators
                            └── Reporting Context     │ Mappers

Application Layer            Aggregates               Domain Layer
                            ├── Book Aggregate        │ Book Entity
                            ├── Rating Aggregate      │ Rating Entity
                            ├── User Aggregate        │ User Entity
                            └── Review Aggregate      │ Domain Events

Data Layer                   Repositories &           Infrastructure Layer
                            Persistence              │ DbContext
                            ├── Books DB              │ Migrations
                            ├── Ratings DB            │ EF Core
                            └── Events DB             │ Event Store
```

#### Bounded Contexts (DDD)

Each microservice corresponds to a bounded context:

```
Books Service (Bounded Context)
├── Language: Book Catalog Ubiquitous Language
├── Aggregates:
│   ├── Book (Root Aggregate)
│   │   ├── Book ID
│   │   ├── Title (localized)
│   │   ├── Author
│   │   ├── ISBN
│   │   ├── Publication Date
│   │   └── Categories
│   │
│   ├── BookCategory
│   └── BookAuthor
│
├── Events:
│   ├── BookCreatedEvent
│   ├── BookUpdatedEvent
│   ├── BookDeletedEvent
│   └── BookMovedEvent (category change)
│
└── Repository: IRepository<Book>

────────────────────────────────────────

Ratings Service (Bounded Context)
├── Language: Feedback & Rating Ubiquitous Language
├── Aggregates:
│   ├── Rating (Root Aggregate)
│   │   ├── Rating ID
│   │   ├── Book ID (reference, not ForeignKey)
│   │   ├── User ID (reference)
│   │   ├── Score (1-5)
│   │   ├── Review Text
│   │   ├── Created Date
│   │   └── Moderation Status
│   │
│   └── RatingStatistics (Aggregate)
│       ├── Book ID
│       ├── Total Count
│       ├── Star Distribution
│       └── Average Score
│
├── Events:
│   ├── RatingSubmittedEvent
│   ├── RatingUpdatedEvent
│   ├── RatingDeletedEvent
│   └── RatingModerationEvent
│
└── Repository: IRepository<Rating>

────────────────────────────────────────

Users Service (Bounded Context)
├── Language: User Management & Identity Ubiquitous Language
├── Aggregates:
│   ├── User (Root Aggregate)
│   │   ├── User ID
│   │   ├── Email
│   │   ├── Full Name
│   │   ├── Password (hashed)
│   │   ├── Registration Date
│   │   └── Status (Active, Suspended, Deleted)
│   │
│   ├── UserProfile
│   │   ├── Bio
│   │   ├── Avatar
│   │   ├── Preferred Language
│   │   └── Timezone
│   │
│   └── UserPreferences
│       ├── Email Notifications
│       ├── Privacy Level
│       └── Theme (Light/Dark)
│
├── Events:
│   ├── UserRegisteredEvent
│   ├── UserProfileUpdatedEvent
│   ├── UserSuspendedEvent
│   └── UserDeletedEvent
│
└── Repository: IRepository<User>

────────────────────────────────────────

Admin Service (Bounded Context)
├── Language: Moderation & Governance Ubiquitous Language
├── Aggregates:
│   ├── ModerationCase (Root Aggregate)
│   │   ├── Case ID
│   │   ├── Reported Item ID
│   │   ├── Reporter ID
│   │   ├── Reason
│   │   ├── Status (Pending, InReview, Resolved)
│   │   ├── Action Taken
│   │   └── Resolution Date
│   │
│   └── AuditLog
│       ├── User ID
│       ├── Action
│       ├── Timestamp
│       ├── IP Address
│       └── Changes
│
├── Events:
│   ├── ReviewReportedEvent
│   ├── ReviewModerationEvent
│   ├── UserSuspendedEvent
│   └── AuditLogCreatedEvent
│
└── Repository: IRepository<ModerationCase>

────────────────────────────────────────

Reporting Service (Bounded Context)
├── Language: Analytics & Insights Ubiquitous Language
├── Aggregates:
│   ├── BookAnalytics (Aggregate)
│   │   ├── Book ID
│   │   ├── Total Ratings
│   │   ├── Average Score
│   │   ├── Rating Distribution
│   │   ├── Trending Status
│   │   └── Last Updated
│   │
│   ├── UserAnalytics
│   │   ├── User ID
│   │   ├── Ratings Count
│   │   ├── Reviews Count
│   │   ├── Activity Score
│   │   └── Joined Date
│   │
│   └── Report
│       ├── Report ID
│       ├── Type (BookAnalytics, TrendAnalysis)
│       ├── Content
│       ├── Generated Date
│       └── Format (PDF, Excel, CSV)
│
├── Events:
│   ├── AnalyticsUpdatedEvent
│   ├── ReportGeneratedEvent
│   ├── TrendAnalyzedEvent
│   └── ExportCompletedEvent
│
└── Repository: IRepository<BookAnalytics>
```

#### CQRS Pattern Implementation

```
Each Bounded Context separates Commands and Queries:

Books Service CQRS
──────────────────

COMMANDS (Write Operations - handled by MediatR)
├── CreateBookCommand
│   ├── Handler: CreateBookCommandHandler
│   ├── Validation: CreateBookValidator
│   ├── Side Effect: Publishes BookCreatedEvent
│   └── Changes: Books table
│
├── UpdateBookCommand
│   ├── Handler: UpdateBookCommandHandler
│   ├── Validation: UpdateBookValidator
│   ├── Side Effect: Publishes BookUpdatedEvent
│   └── Changes: Books table
│
└── DeleteBookCommand
    ├── Handler: DeleteBookCommandHandler
    ├── Validation: DeleteBookValidator (check dependencies)
    ├── Side Effect: Publishes BookDeletedEvent
    └── Changes: Books table (soft delete)

QUERIES (Read Operations - optimized for read model)
├── GetBooksQuery
│   ├── Handler: GetBooksQueryHandler
│   ├── Returns: IEnumerable<BookDto>
│   ├── Filtering: by author, category, rating
│   ├── Pagination: skip, take
│   └── Source: Read model / Redis cache
│
├── GetBookByIdQuery
│   ├── Handler: GetBookByIdQueryHandler
│   ├── Returns: BookDetailDto (with ratings aggregate)
│   ├── Caching: Redis (5 min TTL)
│   └── Source: Optimized read model
│
└── SearchBooksQuery
    ├── Handler: SearchBooksQueryHandler
    ├── Returns: Paged<BookDto>
    ├── Search: Full-text search
    ├── Sorting: relevance, rating, date
    └── Source: Elasticsearch / SQL search

Write Model (Events → State)
├── Events: BookCreatedEvent, BookUpdatedEvent
├── Handler: Updates Books aggregate in database
├── Projection: Feeds into read model
└── Storage: Event Store / Audit Trail

Read Model (Optimized for queries)
├── Books table (denormalized for reads)
├── BookSearch index (full-text)
├── Redis cache (hot data)
└── Analytics table (aggregated statistics)
```

#### Data Architecture

```
TOGAF Data Architecture Layer

Databases (Per-Service - Database per Microservice Pattern)
├── Books Service
│   ├── Books table
│   ├── BookCategories table
│   ├── BookAuthors table
│   └── Events table (Event Store)
│
├── Ratings Service
│   ├── Ratings table
│   ├── RatingStatistics table (denormalized)
│   └── Events table
│
├── Users Service
│   ├── Users table
│   ├── UserProfiles table
│   ├── UserPreferences table
│   └── Events table
│
├── Admin Service
│   ├── ModerationCases table
│   ├── AuditLogs table
│   └── Events table
│
└── Reporting Service
    ├── BookAnalytics table (materialized view)
    ├── UserAnalytics table
    ├── Reports table
    └── Events table (read-only mirror)

Caching Layer
├── Redis (distributed cache)
│   ├── Book detail cache (5 min TTL)
│   ├── User profile cache (10 min TTL)
│   ├── Rating statistics cache (1 min TTL)
│   └── Session cache (30 min TTL)
│
└── Distributed Query Cache
    ├── Query results cache
    └── Search index cache

Offline Client Databases
├── SQLite (Mobile/Web offline)
│   ├── Books cache
│   ├── Ratings cache
│   ├── User data cache
│   ├── SyncQueue (pending mutations)
│   └── LocalSettings
│
└── Synchronization
    ├── Detect changes
    ├── Conflict resolution (last-write-wins)
    ├── Batch upload
    └── Sync confirmation
```

### Phase D: Technology Architecture

**Goal**: Define technology standards and infrastructure

#### Technology Stack (TOGAF Technology Domain)

```
TOGAF Technology Layer → Implementation

Presentation Layer
├── Technology: Blazor Server, .NET MAUI
├── Protocols: HTTP/2, WebSocket (SignalR)
├── Standards: REST API (RFC 7231), OpenAPI 3.0
├── Security: TLS 1.3, SameSite cookies
└── CNCF: N/A (client-side)

Application Layer
├── Framework: ASP.NET Core 10.0 (Minimal APIs)
├── Patterns: CQRS + MediatR, Vertical Slice Architecture
├── Standards: .NET 10.0
├── Security: JWT (OpenID Connect), WASP compliance
├── CNCF: N/A (application code)

Integration Layer
├── Messaging: MassTransit (event publishing)
├── Broker: RabbitMQ (AMQP protocol)
├── Pattern: Event-Driven, Publish-Subscribe
├── Standards: Cloud Events format
├── CNCF: CNCF Project (messaging infrastructure)

Data Layer
├── Online: SQL Server 2022 (SQL Server 2019+)
├── Offline: SQLite 3.x
├── ORM: Entity Framework Core 10.0
├── Patterns: Repository, Unit of Work
├── CNCF: N/A (relational database)

Service Invocation
├── Method 1: DAPR (cloud-agnostic)
│   ├── Service Invocation: HTTP/gRPC
│   ├── State Management: Key-value store abstraction
│   └── Pub/Sub: Multiple backend support
│
├── Method 2: Direct HTTP
│   ├── Client: HttpClientFactory with Polly
│   ├── Resilience: Retry, circuit breaker, timeout
│   └── Observability: OpenTelemetry instrumentation
│
└── Method 3: DAPR State Management
    ├── Redis: Development/staging
    ├── Cosmos DB: Azure production
    ├── DynamoDB: AWS production
    └── Firestore: GCP production

Observability Stack
├── Tracing: OpenTelemetry (W3C Trace Context)
├── Collector: OTEL Collector or Jaeger
├── Metrics: Prometheus (pull model)
├── Logging: Serilog (structured JSON)
├── Visualization: Grafana
├── APM: DataDog (production)
└── CNCF: OpenTelemetry, Prometheus, Grafana (CNCF projects)

Security Stack
├── Identity: Keycloak (OpenID Connect)
├── Secrets: Azure Key Vault / AWS Secrets Manager / GCP Secret Manager
├── Encryption: AES-256 (symmetric), RSA-4096 (asymmetric)
├── Transport: TLS 1.3
├── Zero Trust: Every access authenticated & authorized
└── Compliance: WASP security framework

Container & Orchestration
├── Runtime: Podman / Docker
├── Orchestration: Kubernetes (CNCF)
├── Service Mesh: Istio (optional, CNCF)
├── Networking: CNI (Calico/Flannel)
├── Storage: Persistent Volumes (CNCF)
├── Package Manager: Helm (CNCF)
└── CNCF: Kubernetes, Containerd, Istio, Helm

Infrastructure as Code
├── Cloud Provisioning: Terraform (multi-cloud)
├── Configuration: .NET Aspire (local development)
├── GitOps: ArgoCD (optional, CNCF)
└── CI/CD: GitHub Actions

Standards & Compliance
├── API: OpenAPI 3.0 (REST endpoints)
├── Security: WASP Top 10 compliance
├── Logging: ISO 27001 audit logging
├── Data Protection: GDPR, CCPA ready
├── Accessibility: WCAG 2.1 Level AA
└── Internationalization: Unicode, 7-language support
```

### Phase E: Opportunities & Solutions

**Goal**: Identify transformation initiatives and solution blueprints

#### Quick Wins (0-3 months)

```
1. Performance Optimization
   ├── Redis caching implementation
   ├── Query optimization (indexes, execution plans)
   ├── Database denormalization for read models
   └── Expected Impact: 40-50% latency reduction

2. Security Hardening
   ├── Zero Trust implementation
   ├── Rate limiting deployment
   ├── Audit logging enablement
   └── Expected Impact: 100% compliance with WASP

3. Observability
   ├── OpenTelemetry instrumentation
   ├── Grafana dashboard setup
   ├── Alert rules configuration
   └── Expected Impact: 90% visibility into system behavior
```

#### Medium-Term Initiatives (3-9 months)

```
1. Service Mesh Implementation (Optional)
   ├── Istio deployment
   ├── Traffic management policies
   ├── Security policies (mTLS)
   └── Expected Impact: Automated resilience, security

2. CQRS Optimization
   ├── Read model optimization
   ├── Event sourcing implementation
   ├── Projection optimization
   └── Expected Impact: Sub-100ms query latency

3. Multi-Region Deployment
   ├── Data replication setup
   ├── Geo-routing implementation
   ├── Failover automation
   └── Expected Impact: 99.99% availability
```

#### Strategic Initiatives (9-24 months)

```
1. AI/ML Integration
   ├── Recommendation engine
   ├── Anomaly detection
   ├── User behavior prediction
   └── Expected Impact: 30% engagement increase

2. Mobile App Expansion
   ├── Advanced offline scenarios
   ├── Push notifications
   ├── Native integrations
   └── Expected Impact: 2x user growth

3. Data Warehouse
   ├── Data lake implementation
   ├── Advanced analytics
   ├── Business intelligence
   └── Expected Impact: Real-time insights
```

### Phase F: Migration Planning

**Goal**: Roadmap implementation and change management**

#### Migration Waves

```
Wave 1: Foundation (Months 1-3)
├── Set up TOGAF governance board
├── Implement Zero Trust architecture
├── Deploy Kubernetes cluster
├── Set up CI/CD pipeline
└── Deliverable: Production-ready platform

Wave 2: Optimization (Months 4-6)
├── Implement CQRS optimization
├── Deploy Redis caching
├── Set up service mesh (optional)
├── Complete observability stack
└── Deliverable: High-performance platform

Wave 3: Enhancement (Months 7-12)
├── Multi-region deployment
├── Advanced analytics
├── Mobile app refinement
├── Disaster recovery testing
└── Deliverable: Enterprise-grade platform

Wave 4: Innovation (Months 13+)
├── AI/ML features
├── Advanced mobile features
├── Data warehouse
├── Strategic partnerships
└── Deliverable: Market-leading platform
```

---

## Part 2: Domain-Driven Design (DDD)

### Ubiquitous Language

```
Core Concepts (Shared language across team)

Books Domain
├── Book: A published literary work (root aggregate)
├── Author: Person who wrote the book
├── Category: Classification of book type
├── ISBN: International Standard Book Number (unique identifier)
└── Publishing Date: When book was released

Ratings Domain
├── Rating: User's numerical assessment (1-5 stars)
├── Review: Detailed written feedback
├── Score: Numeric value of rating
├── Moderation: Review content assessment
└── Analytics: Aggregated rating statistics

Users Domain
├── User: Individual platform member
├── Profile: User's public-facing information
├── Preferences: User's configuration choices
├── Activity: User's interaction history
└── Status: Active, Suspended, Deleted

Admin Domain
├── Moderation: Reviewing reported content
├── AuditLog: Record of system actions
├── Case: Reported content item
├── Action: Resolution taken on report
└── Severity: Level of issue (Low, Medium, High, Critical)
```

### Event Sourcing

```
Event-Driven Domain Events (DDD Core)

All state changes are represented as immutable events:

BookDomain Events
├── BookCreatedEvent
│   ├── BookId: UUID
│   ├── Title: string
│   ├── Author: string
│   ├── ISBN: string
│   ├── CreatedBy: UserId
│   ├── CreatedAt: DateTime
│   └── Version: 1
│
├── BookUpdatedEvent
│   ├── BookId: UUID
│   ├── Changes: {Title?, Author?, Category?}
│   ├── UpdatedBy: UserId
│   ├── UpdatedAt: DateTime
│   └── Version: 2
│
└── BookDeletedEvent
    ├── BookId: UUID
    ├── DeletedBy: UserId
    ├── DeletedAt: DateTime
    └── Version: 3

RatingsDomain Events
├── RatingSubmittedEvent
│   ├── RatingId: UUID
│   ├── BookId: UUID
│   ├── UserId: UUID
│   ├── Score: 1-5
│   ├── ReviewText: string
│   ├── SubmittedAt: DateTime
│   └── Version: 1
│
├── RatingModerationEvent
│   ├── RatingId: UUID
│   ├── ModerationStatus: Approved/Rejected
│   ├── Reason: string
│   ├── ModeratedBy: UserId
│   ├── ModeratedAt: DateTime
│   └── Version: 2
│
└── RatingDeletedEvent
    ├── RatingId: UUID
    ├── Reason: string
    ├── DeletedAt: DateTime
    └── Version: 3
```

### Bounded Context Interactions (Context Mapping)

```
DDD Context Map (How domains interact)

                  Books Service
                       │
         ┌─────────────┼─────────────┐
         │             │             │
    Events:        Contracts:     Shared
BookCreatedEvent  BookDto      Kernel:
BookUpdatedEvent  BookDetailDto  UserId
                                BookId

         │             │             │
         └─────────────┼─────────────┘
                       │
          Published to Event Bus
          (MassTransit + RabbitMQ)
                       │
         ┌─────────────┼─────────────┬─────────────┐
         │             │             │             │
   Ratings Service Admin Service Reporting    Search Service
   (Subscriber)    (Subscriber)   (Subscriber) (Future)
         │             │             │             │
    • Update         • Audit        • Analytics   • Index
      statistics      log           • Track       • Full-text
    • Cache book      • Alert       • Export        search
                                                   
Context Relationship: Conformist Pattern
- Ratings, Admin, Reporting services conform to Books domain events
- No translation needed (shared domain model for these events)
- Enables loose coupling while maintaining consistency
```

---

## Part 3: Clean Architecture + CQRS Implementation

### Layered Architecture (4 Layers)

```
Clean Architecture Layers → Code Organization

┌─────────────────────────────────────────────────┐
│ PRESENTATION LAYER (Endpoints/UI)              │
│ ├── Minimal API endpoints                      │
│ ├── Request/Response mapping                   │
│ ├── Authentication middleware                  │
│ └── Error handling filters                     │
└─────────────────────────────────────────────────┘
                      ↑
                   Depends on
                      ↓
┌─────────────────────────────────────────────────┐
│ APPLICATION LAYER (Use Cases/CQRS)             │
│ ├── MediatR Commands (mutations)               │
│ ├── MediatR Queries (reads)                    │
│ ├── Validators (FluentValidation)              │
│ ├── Mappers (AutoMapper)                       │
│ └── Application Services                       │
└─────────────────────────────────────────────────┘
                      ↑
                   Depends on
                      ↓
┌─────────────────────────────────────────────────┐
│ DOMAIN LAYER (Business Logic/Entities)         │
│ ├── Aggregate Roots (Book, Rating, User)       │
│ ├── Domain Events (BookCreatedEvent)           │
│ ├── Value Objects (Rating: 1-5)                │
│ ├── Domain Services                            │
│ └── Domain Exceptions                          │
└─────────────────────────────────────────────────┘
                      ↑
                   Depends on
                      ↓
┌─────────────────────────────────────────────────┐
│ INFRASTRUCTURE LAYER (External Systems)        │
│ ├── EF Core DbContext (persistence)            │
│ ├── Repository implementation                  │
│ ├── Event publishing (MassTransit)             │
│ ├── Keycloak integration                       │
│ ├── Cache implementation (Redis)               │
│ └── External API clients                       │
└─────────────────────────────────────────────────┘

Dependency Rule: Inner layers are independent, outer layers depend on inner
```

### Vertical Slice Organization

```
Each feature is a complete vertical slice:

Features/CreateBook/
├── CreateBookCommand.cs          (CQRS Command)
├── CreateBookCommandHandler.cs   (Application layer)
├── CreateBookValidator.cs        (Input validation)
├── CreateBookRequest.cs          (DTO)
├── CreateBookResponse.cs         (DTO)
├── CreateBookMapper.cs           (Mapping logic)
└── CreateBookEndpoint.cs         (Presentation layer)

Vertical Slice Pattern Benefits:
✓ Self-contained feature (easier to understand)
✓ Minimal cross-cutting concerns
✓ Easy to add/modify/delete features
✓ Reduced cognitive load
✓ Better for team collaboration
```

### CQRS + MediatR Implementation

```
Command Query Responsibility Segregation

Write Side (Commands)
────────────────────────────────────────────

1. Client sends CreateBookCommand
   └── CreateBook { Title, Author, ISBN }

2. MediatR routes to CreateBookCommandHandler
   ├── Validate input (CreateBookValidator)
   ├── Check business rules
   ├── Create Book aggregate
   ├── Save to database
   └── Publish BookCreatedEvent

3. Event published to message broker
   └── Other services subscribe (Ratings, Admin, Reporting)

4. Response returned to client
   └── HTTP 201 Created + BookId

Read Side (Queries)
────────────────────────────────────────────

1. Client sends GetBooksQuery
   └── GetBooks { Skip, Take, Filter }

2. MediatR routes to GetBooksQueryHandler
   ├── Query read model (optimized for reads)
   ├── Apply filters/pagination/sorting
   ├── Check cache (Redis)
   └── Return results

3. Response returned to client
   └── HTTP 200 OK + Books[]

Separation Benefits:
✓ Optimized write model (normalized)
✓ Optimized read model (denormalized)
✓ Scalability (read replicas)
✓ Performance (caching opportunities)
✓ Clear responsibility (command vs query)

Data Flow:
Write → Event → Event Bus → Projection → Read Model → Query Handler
```

---

## Part 4: Zero Trust Security Architecture

**Principle**: Never trust, always verify. Every access request authenticated & authorized.

### Zero Trust Model

```
Zero Trust Security Layers

Layer 1: Network Identity
├── Service Identity: DAPR/mTLS
├── Certificate Management: Let's Encrypt / Cloud CA
├── Network Policies: Kubernetes NetworkPolicy
└── Segmentation: Per-service firewall rules

Layer 2: Authentication (Verify Identity)
├── User Auth: Keycloak OpenID Connect
├── Service-to-Service: mTLS certificates
├── Device Identity: Client certificate
├── Token Validation: JWT signature verification
└── Token Refresh: Automated rotation

Layer 3: Authorization (Verify Permission)
├── Role-Based Access Control (RBAC)
│   ├── Admin: Full platform access
│   ├── Moderator: Content moderation
│   ├── Reviewer: Submit ratings/reviews
│   └── Reader: Browse books
│
├── Resource-Based Access Control (RBAC)
│   ├── Own content: User can edit/delete own ratings
│   ├── Admin content: Only admins can moderate
│   └── System content: Only authorized services
│
└── Attribute-Based Access Control (ABAC)
    ├── Time-based: Access only during business hours
    ├── Location-based: Restrict by IP/region
    ├── Device-based: Only trusted devices
    └── Behavior-based: Anomaly detection

Layer 4: Encryption (Protect Data)
├── At Rest: AES-256 encryption
│   ├── Database: Transparent encryption (TDE)
│   ├── Backups: Encrypted storage
│   └── Secrets: Encrypted vault
│
├── In Transit: TLS 1.3
│   ├── Service-to-service: mTLS
│   ├── Client-to-API: HTTPS
│   └── Replication: Encrypted channels
│
└── At Keys: Key management
    ├── Key rotation: Automatic (90 days)
    ├── Key storage: Hardware security module (HSM)
    └── Key access: Audit logged

Layer 5: Audit & Monitoring
├── Access Logging: Every API call logged
├── Change Tracking: Data modifications logged
├── Anomaly Detection: Unusual behavior flagged
├── Alert Rules: Immediate escalation on incidents
└── Compliance Reports: GDPR, SOC 2, HIPAA ready
```

### Implementation Example

```csharp
// Zero Trust in Practice

// 1. Authentication (Verify Identity)
[Authorize]  // JWT token required
app.MapGet("/api/books", GetBooks);

// 2. Authorization (Verify Permission)
[Authorize(Roles = "Reader,Reviewer")]  // Role check
app.MapPost("/api/ratings", CreateRating);

// 3. Resource Ownership (Attribute-based)
app.MapDelete("/api/ratings/{id}", DeleteRating)
    .RequireAuthorization(policy =>
        policy.Requirements.Add(new RatingOwnerRequirement()));

// 4. Encryption (Transparent)
var sensitiveData = EncryptionService.Encrypt(userData);  // AES-256
await _repository.SaveAsync(sensitiveData);

// 5. Audit Logging
_auditLog.LogAccess(userId, "DELETE", "/api/ratings/123", 
    success: true, details: "Deleted own rating");
```

---

## Part 5: CNCF Cloud Native Patterns

### Cloud Native Principles

```
CNCF Definition: Cloud Native Technologies

12-Factor App + Kubernetes-Native Patterns

1. Base Code
   ✓ Single codebase tracked in git
   ✓ Deploy different versions per environment
   ✓ Infrastructure-as-code (Terraform)

2. Dependencies
   ✓ Explicit NuGet dependencies (*.csproj)
   ✓ No system-wide packages
   ✓ Docker/container includes all deps

3. Config
   ✓ Kubernetes ConfigMaps for configuration
   ✓ Secrets for sensitive data
   ✓ Environment variables for deployment

4. Backing Services
   ✓ Database: Treat as attached service
   ✓ Cache: Redis service
   ✓ Message broker: RabbitMQ service
   ✓ Identity: Keycloak service

5. Build/Release/Run
   ✓ Build: Compile .NET application
   ✓ Release: Package in container
   ✓ Run: Deploy to Kubernetes

6. Processes
   ✓ Stateless services
   ✓ Horizontal scaling
   ✓ Load balancing (Kubernetes Service)

7. Port Binding
   ✓ Self-contained web server
   ✓ Listens on specific port
   ✓ No separate application server

8. Concurrency
   ✓ Process model (Kubernetes Pods)
   ✓ Horizontal scaling (ReplicaSet)
   ✓ Load balancing

9. Disposability
   ✓ Fast startup/shutdown
   ✓ Graceful termination
   ✓ Crash-only design

10. Dev/Prod Parity
    ✓ Same containerization locally & production
    ✓ Same backing services (Testcontainers)
    ✓ Identical configurations

11. Logs
    ✓ Write to stdout
    ✓ Aggregation by platform (Kubernetes, DataDog)
    ✓ Structured JSON logging

12. Admin Tasks
    ✓ Database migrations (EF Core)
    ✓ Jobs (Hangfire, Kubernetes CronJob)
    ✓ One-off tasks (kubectl exec)
```

### Kubernetes-Native Architecture

```
BookRatings on Kubernetes

┌──────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (AKS, EKS, GKE)                       │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ bookratings Namespace                              │ │
│  │                                                    │ │
│  │  Services (Deployments)                           │ │
│  │  ├── books-service (3 replicas)                   │ │
│  │  ├── ratings-service (3 replicas)                 │ │
│  │  ├── users-service (3 replicas)                   │ │
│  │  ├── admin-service (2 replicas)                   │ │
│  │  ├── reporting-service (2 replicas)               │ │
│  │  └── api-gateway (2 replicas)                     │ │
│  │                                                    │ │
│  │  Data Services (StatefulSets)                     │ │
│  │  ├── sql-server (1 replica, persistent storage)   │ │
│  │  ├── rabbitmq (3 replicas, clustered)             │ │
│  │  ├── redis (1 primary + 2 replicas)               │ │
│  │  └── postgres (1 primary + 2 replicas)            │ │
│  │                                                    │ │
│  │  Ingress & Load Balancing                         │ │
│  │  ├── Ingress Controller (nginx)                   │ │
│  │  ├── TLS termination                              │ │
│  │  ├── Rate limiting rules                          │ │
│  │  └── WAF rules                                    │ │
│  │                                                    │ │
│  │  Observability                                    │ │
│  │  ├── Prometheus (metrics)                         │ │
│  │  ├── Grafana (dashboards)                         │ │
│  │  ├── Jaeger (distributed tracing)                 │ │
│  │  ├── Loki (log aggregation)                       │ │
│  │  └── AlertManager (alerting)                      │ │
│  │                                                    │ │
│  │  DAPR Sidecars (Service Mesh, optional)           │ │
│  │  ├── Service invocation                           │ │
│  │  ├── State management                             │ │
│  │  ├── Pub/Sub messaging                            │ │
│  │  └── Secrets management                           │ │
│  │                                                    │ │
│  │  ConfigMaps & Secrets                             │ │
│  │  ├── app-config (non-sensitive config)            │ │
│  │  ├── database-secrets (encrypted)                 │ │
│  │  ├── api-keys (encrypted)                         │ │
│  │  └── tls-certificates (TLS)                       │ │
│  │                                                    │ │
│  │  Storage                                          │ │
│  │  ├── PersistentVolumeClaims (databases)           │ │
│  │  ├── StorageClass (SSD, standard)                 │ │
│  │  └── Snapshots (backup strategy)                  │ │
│  │                                                    │ │
│  │  Networking                                       │ │
│  │  ├── Service (internal DNS)                       │ │
│  │  ├── NetworkPolicy (firewall)                     │ │
│  │  └── CoreDNS (service discovery)                  │ │
│  │                                                    │ │
│  │  Auto-Scaling                                     │ │
│  │  ├── HPA (Horizontal Pod Autoscaler)              │ │
│  │  │   ├── Books: 3-10 replicas (CPU > 70%)         │ │
│  │  │   └── Ratings: 2-8 replicas (Memory > 80%)     │ │
│  │  │                                                 │ │
│  │  │ VPA (Vertical Pod Autoscaler)                  │ │
│  │  │   └── Auto-adjust resource requests            │ │
│  │  │                                                 │ │
│  │  └── CA (Cluster Autoscaler)                      │ │
│  │      └── Add nodes when needed                    │ │
│  │                                                    │ │
│  │  Health Checks                                    │ │
│  │  ├── Liveness Probe (/health/live)                │ │
│  │  │   └── Restart if unhealthy                     │ │
│  │  │                                                 │ │
│  │  └── Readiness Probe (/health/ready)              │ │
│  │      └── Remove from load balancer if not ready   │ │
│  │                                                    │ │
│  │  Resource Management                              │ │
│  │  ├── Requests (guaranteed)                        │ │
│  │  │   └── CPU: 250m, Memory: 512Mi                 │ │
│  │  │                                                 │ │
│  │  └── Limits (maximum)                             │ │
│  │      └── CPU: 1000m, Memory: 2Gi                  │ │
│  │                                                    │ │
│  │  Policies                                         │ │
│  │  ├── Pod Disruption Budget (PDB)                  │ │
│  │  │   └── Maintain availability during updates     │ │
│  │  │                                                 │ │
│  │  ├── Network Policy                               │ │
│  │  │   └── Egress/ingress rules per service         │ │
│  │  │                                                 │ │
│  │  └── Security Policy (PSP/Pod Security)           │ │
│  │      └── Prevent privileged containers            │ │
│  └────────────────────────────────────────────────────┘ │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ External Services (cloud-managed)                  │ │
│  │ ├── Key Vault / Secrets Manager (secrets)          │ │
│  │ ├── Container Registry (image storage)             │ │
│  │ ├── Load Balancer (cloud provider)                 │ │
│  │ └── DNS (cloud provider)                           │ │
│  └────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

### GitOps & Continuous Deployment

```
GitOps Pipeline (ArgoCD + GitHub)

Code Repository
├── main branch
├── develop branch
└── feature branches
        │
        ├─ Pull Request
        └─ Code Review
                │
                ├─ GitHub Actions
                │   ├── Build
                │   ├── Test
                │   ├── Security Scan
                │   └── Container Build
                │
                ├─ Quality Gates
                │   ├── Code coverage > 80%
                │   ├── SAST scan passed
                │   └── All tests passed
                │
                └─ Merge to main
                        │
                        ├─ Push Docker image
                        ├─ Update manifest
                        └─ Commit to GitOps repo

GitOps Repository (Infrastructure-as-Code)
├── kubernetes/
│   ├── base/
│   │   ├── books-deployment.yaml
│   │   ├── ratings-deployment.yaml
│   │   └── kustomization.yaml
│   │
│   └── overlays/
│       ├── dev/
│       │   └── kustomization.yaml (dev values)
│       │
│       ├── staging/
│       │   └── kustomization.yaml (staging values)
│       │
│       └── prod/
│           └── kustomization.yaml (prod values)
│
└── argocd/
    ├── application.yaml
    ├── notification.yaml
    └── sync-policy.yaml
        │
        ├─ Continuous Sync
        ├─ Auto-prune
        └─ Rollback on failure

Continuous Deployment Flow:
1. Push code to main branch
2. GitHub Actions builds & tests
3. Pushes image to registry
4. Updates manifest in GitOps repo
5. ArgoCD detects change
6. Applies manifests to cluster
7. Kubernetes rolls out deployment
8. Health checks verify success
9. Rollback on failure (automatic)
```

---

## Part 6: Observability (OpenTelemetry + Prometheus + Grafana)

### Three Pillars of Observability

```
Observability = Metrics + Logs + Traces

1. METRICS (What is happening?)
   ├── Request count (counter)
   ├── Request latency (histogram)
   ├── Error rate (rate)
   ├── CPU usage (gauge)
   ├── Memory usage (gauge)
   ├── Database queries (counter)
   └── Business metrics (ratings submitted, books added)

2. LOGS (When did it happen?)
   ├── Structured logs (JSON)
   ├── Correlation IDs (trace context)
   ├── Log levels (Debug, Info, Warning, Error)
   ├── Log aggregation (ELK, Loki)
   └── Log retention (30 days, searchable)

3. TRACES (How did it happen?)
   ├── Distributed tracing (OpenTelemetry)
   ├── Span attributes (request ID, service name)
   ├── Trace visualization (Jaeger)
   ├── Root cause analysis (error traces)
   └── Performance profiling (flame graphs)
```

### OpenTelemetry Implementation

```
OpenTelemetry Stack (CNCF Project)

Components:
├── Instrumentation (SDKs)
│   ├── ASP.NET Core
│   ├── Entity Framework Core
│   ├── HTTP Client
│   ├── SQL Client
│   └── Custom (Application code)
│
├── Context Propagation
│   ├── W3C Trace Context (standard)
│   ├── Trace ID: Unique per request
│   ├── Span ID: Unique per operation
│   └── Baggage: Custom context data
│
├── Exporters
│   ├── OTEL Collector
│   │   ├── gRPC receiver
│   │   ├── Batch processor
│   │   ├── Jaeger exporter
│   │   └── Prometheus exporter
│   │
│   └── Direct exporters
│       ├── Jaeger (tracing)
│       ├── Prometheus (metrics)
│       └── DataDog (production APM)
│
└── Backend Systems
    ├── Jaeger (distributed tracing)
    │   ├── Web UI (trace visualization)
    │   ├── Dependency analysis
    │   └── Performance metrics
    │
    ├── Prometheus (metrics)
    │   ├── Scraping interval (15s)
    │   ├── Retention (15 days)
    │   ├── PromQL queries
    │   └── Recording rules
    │
    └── Grafana (dashboards)
        ├── Service dashboards
        ├── Database performance
        ├── Business metrics
        └── Alert visualization

Data Flow:
Application Instrumentation
    ↓ (Spans + Metrics)
OTEL Collector (processor + exporter)
    ↓ (gRPC)
Backends (Jaeger, Prometheus)
    ↓
Visualization (Grafana, Jaeger UI)
    ↓
Dashboards & Alerts
```

### Observability in Action

```
Request Flow with Observability

User Request: GET /api/books?skip=0&take=10
    │
    ├─ [Trace] Create span "GET /api/books"
    ├─ [Metric] Increment "http_requests_total"
    │
    ├─ API Gateway
    │   ├─ [Span] Add baggage: {"user_id": "123"}
    │   ├─ [Metric] Auth latency
    │   └─ [Log] "User 123 requesting books"
    │
    ├─ Books Service Handler
    │   ├─ [Span] "GetBooksQuery.Handle"
    │   ├─ [Metric] Start timer
    │   │
    │   ├─ Cache Check
    │   │   ├─ [Span] "Redis.Get"
    │   │   ├─ [Metric] "cache_hits" or "cache_misses"
    │   │   └─ [Log] "Cache miss for books"
    │   │
    │   ├─ Database Query
    │   │   ├─ [Span] "DbContext.ToListAsync"
    │   │   ├─ [Metric] "db_query_duration"
    │   │   └─ [Log] "Query Books table"
    │   │
    │   ├─ Response Mapping
    │   │   ├─ [Span] "Mapper.Map"
    │   │   └─ [Metric] "mapping_duration"
    │   │
    │   └─ Cache Set
    │       ├─ [Span] "Redis.Set"
    │       └─ [Metric] "cache_writes"
    │
    ├─ [Metric] Stop timer
    ├─ [Metric] Record latency: 45ms
    ├─ [Log] "Request completed: 200 OK"
    │
    └─ Response: 10 books + metrics + trace context

Observability Insights:
✓ Total latency: 45ms
✓ Database query: 30ms (66%)
✓ Cache miss detected
✓ User 123 active
✓ All requests traced
✓ Metrics for alerting
✓ Logs for debugging
```

---

## Part 7: Architecture Integration Summary

### How TOGAF + DDD + Clean Architecture + CQRS work together

```
Request Journey (End-to-End with all patterns)

1. User submits rating (UI)
   └─ HTTP POST /api/ratings

2. API Gateway (Presentation Layer)
   ├─ [TOGAF] Technology Architecture: REST/HTTP
   ├─ [Zero Trust] Authenticate JWT token
   ├─ [Zero Trust] Authorize: User.role = "Reviewer"
   ├─ [Observability] Create trace, log request
   └─ Route to Books Service

3. Ratings Service Entry (Presentation)
   ├─ [TOGAF] Application Architecture: Minimal API
   ├─ Deserialize request
   └─ Invoke MediatR command

4. CreateRatingCommand (CQRS)
   ├─ [Clean Architecture] Application Layer
   ├─ [CQRS] Command handler routing
   └─ Invoke handler

5. CreateRatingCommandHandler (Application)
   ├─ [Clean Architecture] Application Layer
   ├─ [DDD] Validate using domain rules
   ├─ Check book exists (query)
   ├─ Check user not duplicate-rating same book
   ├─ [CQRS] Query read model (separate from write)
   └─ Proceed to domain

6. Rating Aggregate (Domain)
   ├─ [DDD] Domain Layer (pure business logic)
   ├─ [Clean Architecture] No external dependencies
   ├─ Create Rating aggregate
   ├─ Validate: Score is 1-5
   ├─ Create domain event: RatingSubmittedEvent
   └─ Return aggregate

7. Persistence (Infrastructure)
   ├─ [Clean Architecture] Infrastructure Layer
   ├─ [DDD] Repository.SaveAsync(rating)
   ├─ EF Core SaveChanges()
   ├─ Persist to SQL Server
   └─ Capture event

8. Event Publishing (Integration)
   ├─ [DDD] Publish RatingSubmittedEvent
   ├─ [Event-Driven] Send to RabbitMQ
   ├─ [TOGAF] Technology: MassTransit
   └─ Multiple services subscribe asynchronously:
       ├─ Ratings Service → Update RatingStatistics
       ├─ Admin Service → Add to moderation queue
       └─ Reporting Service → Update analytics

9. Read Model Projection (CQRS)
   ├─ [CQRS] Update denormalized read model
   ├─ RatingStatistics aggregate updated
   ├─ Cache invalidated
   └─ Ready for next query

10. Response (Presentation)
    ├─ [Clean Architecture] Return to handler
    ├─ [CQRS] No query result (write-side only)
    ├─ Map to response DTO
    ├─ HTTP 201 Created
    └─ [Observability] Record latency, success

Architectural Patterns Involved:
✓ TOGAF: ADM phases A-D (Business, Application, Data, Technology)
✓ DDD: Aggregate, Domain Event, Bounded Context
✓ Clean Architecture: 4 layers, dependency rule
✓ CQRS: Separate command from query, denormalized read model
✓ Event-Driven: Asynchronous, pub-sub, loose coupling
✓ Zero Trust: Authentication + Authorization at every step
✓ Observability: Trace, metric, log at each point
✓ CNCF Cloud Native: Stateless, container-ready, Kubernetes-compatible
```

---

## Part 8: Governance & Architecture Board

### TOGAF Governance Framework

```
Architecture Governance Structure

┌─────────────────────────────────────────────────────────┐
│ ENTERPRISE ARCHITECTURE BOARD                           │
│ (Monthly meeting)                                       │
│ ├── CIO (Chair)                                         │
│ ├── Chief Architect                                     │
│ ├── Business Architecture Lead                          │
│ ├── Application Architecture Lead                       │
│ ├── Infrastructure Architecture Lead                    │
│ └── Security Officer                                    │
│                                                         │
│ Responsibilities:                                       │
│ ├── Approve architecture decisions                      │
│ ├── Review ADRs (Architecture Decision Records)         │
│ ├── Monitor compliance with TOGAF                       │
│ └── Oversee transformation initiatives                  │
└─────────────────────────────────────────────────────────┘

Architecture Change Process (TOGAF Change Management)

1. Propose Change
   ├── ADR (Architecture Decision Record)
   ├── Rationale & alternatives
   ├── Impact analysis
   └── Risk assessment

2. Review (Architecture Board)
   ├── Against principles
   ├── Against standards
   ├── Impact on other services
   └── Cost/benefit analysis

3. Approve
   ├── Vote (unanimous or majority)
   ├── Document decision
   └── Communicate to teams

4. Implement
   ├── Phase gates
   ├── Monitoring & verification
   └── Rollback plan

5. Monitor
   ├── Compliance tracking
   ├── Benefits realization
   └── Feedback loop

Architecture Principles (TOGAF)

Enterprise Principles:
├── Cloud-First: Default to cloud-native solutions
├── Open Standards: Use standard protocols (REST, JSON)
├── Security First: Zero Trust by default
├── Data Driven: Make decisions with metrics
└── Agile: Embrace change, iterate rapidly

Business Principles:
├── Customer Focus: User needs drive decisions
├── Value Delivery: Prioritize business value
├── Efficiency: Optimize for cost & performance
├── Transparency: Visible architecture & decisions
└── Collaboration: Cross-functional teamwork

Application Principles:
├── Microservices: Independently deployable services
├── DDD: Model around business domains
├── CQRS: Separate reads from writes
├── Event-Driven: Async communication preferred
├── Testability: 80%+ code coverage minimum
└── Maintainability: Clean code, well-documented

Technology Principles:
├── CNCF First: Use cloud-native (Kubernetes)
├── API-First: REST/gRPC for integration
├── Containerization: All services containerized
├── Automation: Infrastructure-as-Code (Terraform)
├── Observability: Metrics, logs, traces mandatory
└── Scalability: Horizontal scaling default

Data Principles:
├── Data Governance: Ownership & stewardship
├── Security: Encryption at rest & in transit
├── Privacy: GDPR/CCPA compliant
├── Quality: Master data management
├── Availability: Backup & disaster recovery
└── Retention: Clear data lifecycle policies

Compliance Principles:
├── Audit Trail: All changes logged
├── Access Control: Principle of least privilege
├── Incident Management: RTO/RPO defined
├── Disaster Recovery: 99.99% availability SLA
└── Third-party Risk: Vendor assessments
```

---

## Conclusion

BookRatings implements a **comprehensive, enterprise-grade architecture** that seamlessly integrates:

| Framework | Role | Implementation |
|-----------|------|---|
| **TOGAF** | Enterprise governance & business alignment | ADM phases, business capabilities, architecture board |
| **DDD** | Domain modeling & bounded contexts | Aggregates, ubiquitous language, events |
| **Clean Architecture** | Code organization & separation of concerns | 4-layer architecture, dependency rule |
| **CQRS** | Scalable read/write models | MediatR commands/queries, denormalized reads |
| **Event-Driven** | Loose coupling & asynchronous integration | Domain events, MassTransit, RabbitMQ |
| **Zero Trust** | Security by default | Authentication + authorization every layer |
| **CNCF Cloud Native** | Modern deployment & operations | Kubernetes, containers, 12-factor app |
| **Observability** | System visibility & reliability | OpenTelemetry, Prometheus, Grafana |

This integrated approach delivers:
- ✅ **Business alignment** (TOGAF governance)
- ✅ **Code quality** (Clean Architecture + DDD)
- ✅ **Performance** (CQRS + caching)
- ✅ **Security** (Zero Trust)
- ✅ **Scalability** (Event-driven + Kubernetes)
- ✅ **Reliability** (Observability)
- ✅ **Cloud-readiness** (CNCF standards)
- ✅ **Compliance** (Audit trail, encryption, GDPR)

---

**References**:
- TOGAF 9.2 (Open Group)
- Domain-Driven Design (Eric Evans)
- Clean Architecture (Robert C. Martin)
- Building Microservices (Sam Newman)
- Zero Trust Networks (Evan Gilman, Doug Barth)
- CNCF Landscape (Cloud Native Computing Foundation)
- OpenTelemetry (CNCF)
