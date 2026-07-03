# Podman Test Container Module

## Overview

Centralized Podman testing infrastructure providing containerized databases, message queues, and external services for consistent, reproducible integration tests across all microservices.

## Project Structure

```
Testing/Podman/
├── compose/
│   ├── docker-compose.yml               # Full system with all services
│   ├── docker-compose.books.yml         # Books service dependencies only
│   ├── docker-compose.ratings.yml       # Ratings service dependencies
│   ├── docker-compose.users.yml         # Users service dependencies
│   ├── docker-compose.admin.yml         # Admin service dependencies
│   ├── docker-compose.reporting.yml     # Reporting service dependencies
│   ├── docker-compose.gateway.yml       # Gateway + backend services
│   ├── .env                             # Environment variables
│   ├── .env.ci                          # CI/CD specific overrides
│   ├── .env.dev                         # Development overrides
│   ├── .env.staging                     # Staging overrides
│   └── .env.production                  # Production-like configuration
│
├── images/
│   ├── sqlserver/
│   │   ├── Dockerfile                   # Custom SQL Server image
│   │   ├── init-scripts/
│   │   │   └── init.sql                 # Database initialization
│   │   └── healthcheck.sql
│   │
│   ├── rabbitmq/
│   │   ├── Dockerfile                   # Custom RabbitMQ image
│   │   └── definitions.json             # RabbitMQ exchanges/queues
│   │
│   ├── keycloak/
│   │   ├── Dockerfile
│   │   ├── realm-export.json            # Keycloak realm config
│   │   └── user-seed.json
│   │
│   ├── postgres/
│   │   ├── Dockerfile
│   │   └── init.sql                     # Keycloak DB initialization
│   │
│   └── dapr/
│       ├── Dockerfile
│       ├── components/
│       │   ├── statestore.yaml          # State store component
│       │   ├── pubsub.yaml              # Pub/Sub component
│       │   └── secrets.yaml             # Secrets component
│       └── resiliency.yaml              # Resilience policies
│
├── scripts/
│   ├── startup.sh                       # Start all containers
│   ├── shutdown.sh                      # Stop all containers
│   ├── cleanup.sh                       # Remove containers and volumes
│   ├── health-check.sh                  # Verify container health
│   ├── seed-data.sh                     # Seed test data
│   └── logs.sh                          # Aggregate container logs
│
├── testdata/
│   ├── books-seed.sql                   # Books test data
│   ├── users-seed.sql                   # Users test data
│   ├── ratings-seed.sql                 # Ratings test data
│   └── keycloak-users.json              # Keycloak test users
│
├── BookRatings.Testing.Podman.csproj   # Test utilities library
├── Fixtures/
│   ├── PodmanFixture.cs                 # Base test fixture
│   ├── SqlServerFixture.cs              # SQL Server setup/teardown
│   ├── RabbitMQFixture.cs               # RabbitMQ setup/teardown
│   ├── KeycloakFixture.cs               # Keycloak setup/teardown
│   └── DaprFixture.cs                   # DAPR setup/teardown
│
├── Helpers/
│   ├── ContainerWaitStrategy.cs         # Custom wait strategies
│   ├── HealthCheckHelper.cs             # Container health checks
│   ├── NetworkHelper.cs                 # Container networking
│   └── LogHelper.cs                     # Container log aggregation
│
└── README.md
```

## docker-compose.yml (Full System)

```yaml
version: '3.8'

services:
  # SQL Server
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: bookratings-sqlserver
    environment:
      SA_PASSWORD: ${SQLSERVER_PASSWORD:-YourPassword123!}
      ACCEPT_EULA: "Y"
      MSSQL_PID: "Developer"
    ports:
      - "${SQLSERVER_PORT:-1433}:1433"
    volumes:
      - sqlserver-data:/var/opt/mssql
      - ./images/sqlserver/init-scripts:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD", "/opt/mssql-tools/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", "${SQLSERVER_PASSWORD:-YourPassword123!}", "-Q", "SELECT 1"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 40s
    networks:
      - bookratings-network

  # PostgreSQL (for Keycloak)
  postgres:
    image: postgres:15-alpine
    container_name: bookratings-postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-keycloak}
      POSTGRES_USER: ${POSTGRES_USER:-postgres}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
    ports:
      - "${POSTGRES_PORT:-5432}:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./images/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - bookratings-network

  # RabbitMQ (Message Queue)
  rabbitmq:
    image: rabbitmq:3.12-management-alpine
    container_name: bookratings-rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER:-guest}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:-guest}
    ports:
      - "${RABBITMQ_PORT:-5672}:5672"
      - "${RABBITMQ_MANAGEMENT_PORT:-15672}:15672"
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq
      - ./images/rabbitmq/definitions.json:/etc/rabbitmq/definitions.json:ro
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - bookratings-network

  # Redis (Cache)
  redis:
    image: redis:7-alpine
    container_name: bookratings-redis
    ports:
      - "${REDIS_PORT:-6379}:6379"
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    networks:
      - bookratings-network

  # Keycloak (Identity)
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: bookratings-keycloak
    environment:
      KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN:-admin}
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD:-admin}
      KC_DB: postgres
      KC_DB_URL: "jdbc:postgresql://postgres:5432/${POSTGRES_DB:-keycloak}"
      KC_DB_USERNAME: ${POSTGRES_USER:-postgres}
      KC_DB_PASSWORD: ${POSTGRES_PASSWORD:-postgres}
    ports:
      - "${KEYCLOAK_PORT:-8080}:8080"
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./images/keycloak/realm-export.json:/opt/keycloak/data/import/realm.json:ro
    command: 
      - "start-dev"
      - "--import-realm"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 15s
      timeout: 5s
      retries: 5
    networks:
      - bookratings-network

  # DAPR Placement Service
  dapr-placement:
    image: daprio/dapr:latest
    container_name: bookratings-dapr-placement
    command: ["./placement", "-port", "50005"]
    ports:
      - "${DAPR_PLACEMENT_PORT:-50005}:50005"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:50005/healthz"]
      interval: 10s
      timeout: 3s
      retries: 5
    networks:
      - bookratings-network

  # Jaeger (Distributed Tracing)
  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: bookratings-jaeger
    ports:
      - "${JAEGER_UI_PORT:-16686}:16686"
      - "${JAEGER_GRPC_PORT:-6831}:6831/udp"
      - "${JAEGER_HTTP_PORT:-14268}:14268"
    environment:
      COLLECTOR_OTLP_ENABLED: "true"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:14269"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - bookratings-network

  # Prometheus (Metrics)
  prometheus:
    image: prom/prometheus:latest
    container_name: bookratings-prometheus
    ports:
      - "${PROMETHEUS_PORT:-9090}:9090"
    volumes:
      - ./images/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
    networks:
      - bookratings-network

volumes:
  sqlserver-data:
  postgres-data:
  rabbitmq-data:
  redis-data:
  prometheus-data:

networks:
  bookratings-network:
    driver: bridge
```

## Environment Variables (.env)

```bash
# SQL Server
SQLSERVER_PASSWORD=YourPassword123!
SQLSERVER_PORT=1433

# PostgreSQL (for Keycloak)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=keycloak
POSTGRES_PORT=5432

# RabbitMQ
RABBITMQ_USER=guest
RABBITMQ_PASSWORD=guest
RABBITMQ_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672

# Redis
REDIS_PORT=6379

# Keycloak
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin
KEYCLOAK_PORT=8080

# DAPR
DAPR_PLACEMENT_PORT=50005
DAPR_HTTP_PORT=3500
DAPR_GRPC_PORT=50001

# Jaeger
JAEGER_UI_PORT=16686
JAEGER_GRPC_PORT=6831
JAEGER_HTTP_PORT=14268

# Prometheus
PROMETHEUS_PORT=9090
```

## PodmanFixture.cs (Base Test Fixture)

```csharp
using Testcontainers.MsSql;
using Testcontainers.RabbitMq;
using Testcontainers.Redis;

namespace BookRatings.Testing.Podman.Fixtures;

public class PodmanFixture : IAsyncLifetime
{
    private readonly MsSqlContainer _sqlServer;
    private readonly RabbitMqContainer _rabbitMq;
    private readonly RedisContainer _redis;
    private HttpClient? _httpClient;

    public string SqlServerConnectionString => _sqlServer.GetConnectionString();
    public string RabbitMqHost => _rabbitMq.Hostname;
    public int RabbitMqPort => _rabbitMq.GetMappedPublicPort(5672);
    public string RedisConnectionString => _redis.GetConnectionString();
    public HttpClient HttpClient => _httpClient ??= new HttpClient();

    public PodmanFixture()
    {
        _sqlServer = new MsSqlBuilder()
            .WithPassword("YourPassword123!")
            .Build();

        _rabbitMq = new RabbitMqBuilder()
            .Build();

        _redis = new RedisBuilder()
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _sqlServer.StartAsync();
        await _rabbitMq.StartAsync();
        await _redis.StartAsync();
    }

    public async Task DisposeAsync()
    {
        await _sqlServer.StopAsync();
        await _rabbitMq.StopAsync();
        await _redis.StopAsync();
    }
}
```

## Scripts

### startup.sh

```bash
#!/bin/bash

# Start all Podman containers
echo "Starting Podman containers..."

cd "$(dirname "$0")"

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | grep -v '#' | xargs)
fi

# Start containers
docker-compose up -d

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
./health-check.sh

echo "All services started successfully!"
echo ""
echo "Services available at:"
echo "  SQL Server: localhost:1433"
echo "  RabbitMQ Admin: http://localhost:15672"
echo "  Redis: localhost:6379"
echo "  Keycloak: http://localhost:8080"
echo "  Jaeger UI: http://localhost:16686"
echo "  Prometheus: http://localhost:9090"
```

### cleanup.sh

```bash
#!/bin/bash

# Stop and remove all containers and volumes
echo "Stopping and removing containers..."

docker-compose down -v

# Remove dangling volumes
docker volume prune -f

echo "Cleanup complete!"
```

### health-check.sh

```bash
#!/bin/bash

# Check health of all containers
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    echo "Health check attempt $((attempt + 1))/$max_attempts"
    
    # SQL Server
    if ! docker exec bookratings-sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q "SELECT 1" > /dev/null 2>&1; then
        echo "  ✗ SQL Server not ready"
    else
        echo "  ✓ SQL Server ready"
    fi
    
    # RabbitMQ
    if ! docker exec bookratings-rabbitmq rabbitmq-diagnostics -q ping > /dev/null 2>&1; then
        echo "  ✗ RabbitMQ not ready"
    else
        echo "  ✓ RabbitMQ ready"
    fi
    
    # Redis
    if ! docker exec bookratings-redis redis-cli ping > /dev/null 2>&1; then
        echo "  ✗ Redis not ready"
    else
        echo "  ✓ Redis ready"
    fi
    
    # Keycloak
    if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
        echo "  ✗ Keycloak not ready"
    else
        echo "  ✓ Keycloak ready"
    fi
    
    echo ""
    attempt=$((attempt + 1))
    sleep 2
done

echo "Health check complete!"
```

## Running Tests with Podman

```bash
# Start all services
./Testing/Podman/scripts/startup.sh

# Run integration tests
dotnet test --filter "Category=Integration"

# Run specific service tests
dotnet test Services/Books/BookRatings.Services.Books.Tests --filter "Category=Integration"

# Stop services
./Testing/Podman/scripts/shutdown.sh
```

## Benefits

✅ **Consistency**: Same environment for all developers and CI/CD
✅ **Isolation**: Tests don't affect production or other environments
✅ **Reproducibility**: Container images are versioned and immutable
✅ **Speed**: No need to install/configure databases locally
✅ **Cleanup**: Containers and volumes can be easily cleaned up
✅ **Multi-Service**: Test service interactions with real dependencies
✅ **CI/CD Ready**: Works seamlessly with GitHub Actions, GitLab CI, etc.
