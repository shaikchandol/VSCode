# Load Testing & Performance Benchmarking Guide

## Overview

Comprehensive load testing and performance benchmarking strategy for BookRatings microservices to ensure scalability, reliability, and optimal resource utilization under production-like conditions.

## Project Structure

```
Testing/Performance/
├── LoadTesting/
│   ├── k6/                                  # k6 load testing scripts
│   │   ├── scripts/
│   │   │   ├── books-api.js                # Books API load test
│   │   │   ├── ratings-api.js              # Ratings API load test
│   │   │   ├── users-api.js                # Users API load test
│   │   │   ├── gateway-api.js              # API Gateway load test
│   │   │   ├── smoke-test.js               # Smoke test (baseline)
│   │   │   └── stress-test.js              # Stress test (failure point)
│   │   │
│   │   ├── config/
│   │   │   ├── load.json                   # Load test configuration
│   │   │   ├── stress.json                 # Stress test configuration
│   │   │   └── spike.json                  # Spike test configuration
│   │   │
│   │   └── results/
│   │       ├── baseline.json               # Baseline metrics
│   │       ├── weekly-report.html          # Weekly report
│   │       └── trends.csv                  # Trend analysis
│   │
│   ├── JMeter/
│   │   ├── test-plans/
│   │   │   ├── BookRatings-API.jmx         # JMeter test plan
│   │   │   ├── database-performance.jmx    # Database load test
│   │   │   └── concurrent-users.jmx        # Concurrent user simulation
│   │   │
│   │   └── results/
│   │       └── summary-report.jtl
│   │
│   └── Locust/
│       ├── locustfile.py                   # Locust test scenarios
│       └── requirements.txt
│
├── BenchmarkTesting/
│   ├── BookRatings.Performance.Tests/
│   │   ├── BookRatings.Performance.Tests.csproj
│   │   ├── Benchmarks/
│   │   │   ├── BookServiceBenchmarks.cs    # Book service benchmarks
│   │   │   ├── RatingsServiceBenchmarks.cs # Ratings service benchmarks
│   │   │   ├── DatabaseBenchmarks.cs       # EF Core benchmarks
│   │   │   ├── SerializationBenchmarks.cs  # JSON serialization
│   │   │   └── CachingBenchmarks.cs        # Redis caching
│   │   │
│   │   ├── BenchmarkConfig.cs              # BenchmarkDotNet setup
│   │   ├── BenchmarkResults/
│   │   │   ├── BenchmarkResults-*.html
│   │   │   └── summary.html
│   │   │
│   │   └── results/
│   │       └── BenchmarkDotNet.Artifacts/
│
├── PerformanceTests/
│   ├── BookRatings.Performance.Integration.Tests/
│   │   ├── PerformanceTestBase.cs          # Base class
│   │   ├── BookServicePerformanceTests.cs  # Integration perf tests
│   │   ├── GatewayPerformanceTests.cs      # Gateway perf tests
│   │   └── EndToEndPerformanceTests.cs     # E2E perf tests
│   │
│   └── results/
│       ├── performance-report.json
│       └── trends.csv
│
├── Scripts/
│   ├── run-load-test.sh                    # Execute load tests
│   ├── run-benchmark.sh                    # Execute benchmarks
│   ├── analyze-results.sh                  # Analyze test results
│   ├── generate-report.sh                  # Generate HTML report
│   └── compare-baselines.sh                # Compare with baseline
│
├── Metrics/
│   ├── thresholds.json                     # SLA thresholds
│   ├── baseline-metrics.json               # Performance baseline
│   └── alerts.yaml                         # Alert rules
│
└── Reports/
    ├── weekly-performance-report.md
    ├── monthly-summary.md
    └── trend-analysis.csv
```

## Load Testing with k6

### Installation & Setup

```bash
# Install k6
curl https://get.k6.io | bash

# Or using package manager
brew install k6                              # macOS
choco install k6                             # Windows
sudo apt-get install k6                      # Linux

# Verify installation
k6 version
```

### k6 Smoke Test (Baseline)

**scripts/smoke-test.js**

```javascript
import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Rate, Trend, Counter, Gauge } from 'k6/metrics';

// Custom metrics
export const apiDuration = new Trend('api_duration');
export const errorRate = new Rate('error_rate');
export const requestCount = new Counter('requests_total');
export const activeUsers = new Gauge('users_active');

export const options = {
  stages: [
    { duration: '1m', target: 5 },      // Ramp up to 5 users
    { duration: '3m', target: 5 },      // Stay at 5 users
    { duration: '1m', target: 0 },      // Ramp down
  ],
  thresholds: {
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],  // 95th percentile < 500ms
    'error_rate': ['rate<0.1'],                         // Error rate < 10%
  },
  ext: {
    loadimpact: {
      projectID: 3465991,
      name: 'BookRatings Smoke Test',
    },
  },
};

export default function () {
  activeUsers.add(1);
  
  group('Books API', function () {
    // Get books list
    let res = http.get('http://localhost:5000/api/books?skip=0&take=10');
    check(res, {
      'get books status 200': (r) => r.status === 200,
      'get books duration < 200ms': (r) => r.timings.duration < 200,
    }) || errorRate.add(1);
    
    apiDuration.add(res.timings.duration);
    requestCount.add(1);
    sleep(1);
    
    // Get single book
    const bookId = 1;
    res = http.get(`http://localhost:5000/api/books/${bookId}`);
    check(res, {
      'get book status 200': (r) => r.status === 200,
      'get book duration < 150ms': (r) => r.timings.duration < 150,
    }) || errorRate.add(1);
    
    apiDuration.add(res.timings.duration);
    requestCount.add(1);
    sleep(1);
  });

  group('Ratings API', function () {
    // Get ratings
    let res = http.get('http://localhost:5000/api/ratings?skip=0&take=10');
    check(res, {
      'get ratings status 200': (r) => r.status === 200,
    }) || errorRate.add(1);
    
    apiDuration.add(res.timings.duration);
    requestCount.add(1);
    sleep(1);
  });

  group('Create Rating', function () {
    const payload = JSON.stringify({
      bookId: 1,
      score: 5,
      reviewTitle: 'Excellent book!',
      reviewText: 'This book is amazing!',
    });

    const params = {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + __ENV.API_TOKEN,
      },
    };

    let res = http.post(
      'http://localhost:5000/api/ratings',
      payload,
      params
    );
    check(res, {
      'create rating status 201': (r) => r.status === 201,
      'create rating duration < 300ms': (r) => r.timings.duration < 300,
    }) || errorRate.add(1);
    
    apiDuration.add(res.timings.duration);
    requestCount.add(1);
    sleep(2);
  });

  activeUsers.add(-1);
}
```

### k6 Load Test Configuration

**config/load.json**

```json
{
  "stages": [
    { "duration": "2m", "target": 50 },
    { "duration": "5m", "target": 50 },
    { "duration": "2m", "target": 100 },
    { "duration": "5m", "target": 100 },
    { "duration": "2m", "target": 0 }
  ],
  "thresholds": {
    "http_req_duration": ["p(95)<500", "p(99)<1000"],
    "http_req_failed": ["rate<0.1"],
    "error_rate": ["rate<0.05"]
  },
  "ext": {
    "loadimpact": {
      "projectID": 3465991,
      "name": "BookRatings Full Load Test"
    }
  }
}
```

### k6 Stress Test Configuration

**config/stress.json**

```json
{
  "stages": [
    { "duration": "2m", "target": 100 },
    { "duration": "2m", "target": 200 },
    { "duration": "2m", "target": 300 },
    { "duration": "2m", "target": 400 },
    { "duration": "2m", "target": 500 },
    { "duration": "5m", "target": 500 },
    { "duration": "2m", "target": 0 }
  ],
  "thresholds": {
    "http_req_duration": ["p(95)<1000", "p(99)<2000"],
    "http_req_failed": ["rate<0.2"]
  }
}
```

### Running k6 Tests

```bash
# Smoke test
k6 run scripts/smoke-test.js

# Load test with configuration
k6 run -c config/load.json scripts/books-api.js

# Stress test
k6 run -c config/stress.json scripts/gateway-api.js

# Cloud test (k6 SaaS)
k6 cloud scripts/books-api.js

# Generate report
k6 run --out json=results/output.json scripts/smoke-test.js

# With environment variables
k6 run -e BASE_URL=http://staging:5000 -e API_TOKEN=token scripts/smoke-test.js
```

## BenchmarkDotNet for Code Performance

### Installation

```bash
# Add NuGet package
dotnet add package BenchmarkDotNet

# Optional: For memory profiling
dotnet add package BenchmarkDotNet.Diagnostics.Windows
```

### Book Service Benchmarks

**Benchmarks/BookServiceBenchmarks.cs**

```csharp
using System;
using System.Collections.Generic;
using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Running;
using BookRatings.Services.Books.Features.GetBooks;
using BookRatings.Services.Books.Data;
using Microsoft.EntityFrameworkCore;

namespace BookRatings.Performance.Tests.Benchmarks;

[MemoryDiagnoser]
[SimpleJob(warmupCount: 3, targetCount: 5)]
[Config(typeof(BenchmarkConfig))]
public class BookServiceBenchmarks
{
    private BooksContext _context;
    private IRepository<Book> _repository;

    [GlobalSetup]
    public void GlobalSetup()
    {
        var options = new DbContextOptionsBuilder<BooksContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new BooksContext(options);
        _repository = new Repository<Book>(_context);

        // Seed test data
        SeedTestData();
    }

    [GlobalCleanup]
    public void GlobalCleanup()
    {
        _context?.Dispose();
    }

    [Benchmark]
    public async Task GetBooks_Query()
    {
        var request = new GetBooksRequest { Skip = 0, Take = 10 };
        var handler = new GetBooksHandler(_repository, new AutoMapper.MapperConfiguration(cfg => {}).CreateMapper());
        await handler.Handle(request, CancellationToken.None);
    }

    [Benchmark]
    public async Task GetBooks_WithFiltering()
    {
        var books = await _repository.GetAllAsync(0, 10);
        var filtered = books
            .Where(b => b.Author.Contains("Author"))
            .OrderBy(b => b.Title)
            .ToList();
    }

    [Benchmark]
    [Arguments(100)]
    [Arguments(1000)]
    [Arguments(10000)]
    public async Task GetBooks_Pagination(int totalBooks)
    {
        var books = await _repository.GetAllAsync(skip: 0, take: 10);
        return;
    }

    [Benchmark]
    public async Task CreateBook_InsertPerformance()
    {
        var book = new Book
        {
            Title = $"Benchmark Book {Guid.NewGuid()}",
            Author = "Test Author",
            Isbn = Guid.NewGuid().ToString(),
            PublicationDate = DateTime.UtcNow
        };

        await _repository.AddAsync(book);
        await _context.SaveChangesAsync();
    }

    [Benchmark]
    public async Task UpdateBook_PerformanceTest()
    {
        var book = await _repository.GetByIdAsync(1);
        if (book != null)
        {
            book.Title = $"Updated Title {DateTime.UtcNow}";
            await _repository.UpdateAsync(book);
            await _context.SaveChangesAsync();
        }
    }

    private void SeedTestData()
    {
        for (int i = 1; i <= 1000; i++)
        {
            _context.Books.Add(new Book
            {
                Id = i,
                Title = $"Book {i}",
                Author = $"Author {i % 10}",
                Isbn = $"ISBN-{i}",
                PublicationDate = DateTime.UtcNow.AddDays(-i),
                AverageRating = (decimal)(i % 5) + 1,
                TotalRatings = i * 10
            });
        }
        _context.SaveChanges();
    }
}
```

### Database Performance Benchmarks

**Benchmarks/DatabaseBenchmarks.cs**

```csharp
using BenchmarkDotNet.Attributes;
using Microsoft.EntityFrameworkCore;
using BookRatings.Services.Books.Data;

namespace BookRatings.Performance.Tests.Benchmarks;

[MemoryDiagnoser]
[SimpleJob(warmupCount: 3, targetCount: 5)]
public class DatabaseBenchmarks
{
    private BooksContext _context;

    [GlobalSetup]
    public void Setup()
    {
        var options = new DbContextOptionsBuilder<BooksContext>()
            .UseSqlServer("Server=localhost;Database=BookRatings_Bench;Trusted_Connection=true;")
            .Options;

        _context = new BooksContext(options);
    }

    [Benchmark]
    public async Task EFCore_QueryBooks()
    {
        var books = await _context.Books.Take(100).ToListAsync();
    }

    [Benchmark]
    public async Task EFCore_QueryWithInclude()
    {
        var books = await _context.Books
            .Include(b => b.Ratings)
            .Take(100)
            .ToListAsync();
    }

    [Benchmark]
    public async Task EFCore_AsNoTracking()
    {
        var books = await _context.Books
            .AsNoTracking()
            .Take(100)
            .ToListAsync();
    }

    [Benchmark]
    public async Task EFCore_RawSQL()
    {
        var books = await _context.Books
            .FromSqlRaw("SELECT * FROM Books LIMIT 100")
            .ToListAsync();
    }

    [Benchmark]
    public async Task BulkInsert_1000Items()
    {
        var books = Enumerable.Range(1, 1000)
            .Select(i => new Book
            {
                Title = $"Book {i}",
                Author = $"Author {i}",
                PublicationDate = DateTime.UtcNow
            })
            .ToList();

        await _context.Books.AddRangeAsync(books);
        await _context.SaveChangesAsync();
    }

    [Benchmark]
    public async Task BatchUpdate_1000Items()
    {
        var books = await _context.Books.Take(1000).ToListAsync();
        foreach (var book in books)
        {
            book.AverageRating = 4.5m;
        }
        await _context.SaveChangesAsync();
    }

    [GlobalCleanup]
    public void Cleanup()
    {
        _context?.Dispose();
    }
}
```

### Serialization Performance Benchmarks

**Benchmarks/SerializationBenchmarks.cs**

```csharp
using System.Text.Json;
using BenchmarkDotNet.Attributes;
using Newtonsoft.Json;
using BookRatings.Services.Books.Features.GetBooks;

namespace BookRatings.Performance.Tests.Benchmarks;

[MemoryDiagnoser]
[SimpleJob(warmupCount: 3, targetCount: 5)]
public class SerializationBenchmarks
{
    private GetBooksResponse _response;
    private JsonSerializerOptions _systemTextOptions;

    [GlobalSetup]
    public void Setup()
    {
        _systemTextOptions = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

        _response = new GetBooksResponse
        {
            Books = Enumerable.Range(1, 1000)
                .Select(i => new BookDto
                {
                    Id = i,
                    Title = $"Book {i}",
                    Author = $"Author {i}",
                    AverageRating = 4.5m
                })
                .ToList()
        };
    }

    [Benchmark]
    public string SystemTextJson_Serialize()
    {
        return System.Text.Json.JsonSerializer.Serialize(_response, _systemTextOptions);
    }

    [Benchmark]
    public string NewtonsoftJson_Serialize()
    {
        return JsonConvert.SerializeObject(_response);
    }

    [Benchmark]
    public GetBooksResponse SystemTextJson_Deserialize()
    {
        var json = System.Text.Json.JsonSerializer.Serialize(_response, _systemTextOptions);
        return System.Text.Json.JsonSerializer.Deserialize<GetBooksResponse>(json, _systemTextOptions);
    }

    [Benchmark]
    public GetBooksResponse NewtonsoftJson_Deserialize()
    {
        var json = JsonConvert.SerializeObject(_response);
        return JsonConvert.DeserializeObject<GetBooksResponse>(json);
    }
}
```

### BenchmarkConfig.cs

```csharp
using BenchmarkDotNet.Configs;
using BenchmarkDotNet.Diagnosers;
using BenchmarkDotNet.Exporters;
using BenchmarkDotNet.Exporters.Csv;
using BenchmarkDotNet.Jobs;

namespace BookRatings.Performance.Tests;

public class BenchmarkConfig : ManualConfig
{
    public BenchmarkConfig()
    {
        // Jobs
        AddJob(Job.Default.WithWarmupCount(3).WithIterationCount(5));
        AddJob(Job.ShortRun.WithWarmupCount(2).WithIterationCount(3));

        // Diagnosers
        AddDiagnoser(MemoryDiagnoser.Default);
        AddDiagnoser(new ThreadingDiagnoser());

        // Exporters
        AddExporter(HtmlExporter.Default);
        AddExporter(CsvExporter.Default);
        AddExporter(JsonExporter.Default);

        // Options
        WithOption(ConfigOptions.DisableOptimizationsValidator, true);
    }
}
```

### Running Benchmarks

```bash
# Run all benchmarks
dotnet run -c Release -p Testing/Performance/BookRatings.Performance.Tests/

# Run specific benchmark
dotnet run -c Release -p Testing/Performance/BookRatings.Performance.Tests/ \
  -- --filter "*BookServiceBenchmarks*"

# Generate memory diagrams
dotnet run -c Release -p Testing/Performance/BookRatings.Performance.Tests/ \
  -- --memoryDiagnoser

# Export results
dotnet run -c Release -p Testing/Performance/BookRatings.Performance.Tests/ \
  -- --exportjson
```

## Performance Testing Framework

### PerformanceTestBase.cs

```csharp
using System;
using System.Diagnostics;
using Xunit;

namespace BookRatings.Performance.Integration.Tests;

public abstract class PerformanceTestBase : IAsyncLifetime
{
    protected HttpClient HttpClient { get; set; }
    protected string BaseUrl { get; set; } = "http://localhost:5000";
    
    protected struct PerformanceMetrics
    {
        public long ElapsedMilliseconds { get; set; }
        public long MemoryBefore { get; set; }
        public long MemoryAfter { get; set; }
        public long MemoryAllocated => MemoryAfter - MemoryBefore;
        public int ThreadCount { get; set; }
    }

    protected async Task<PerformanceMetrics> MeasureAsync(Func<Task> operation)
    {
        var memoryBefore = GC.GetTotalMemory(true);
        var threadCountBefore = Process.GetCurrentProcess().Threads.Count;
        
        var stopwatch = Stopwatch.StartNew();
        await operation();
        stopwatch.Stop();
        
        var memoryAfter = GC.GetTotalMemory(false);

        return new PerformanceMetrics
        {
            ElapsedMilliseconds = stopwatch.ElapsedMilliseconds,
            MemoryBefore = memoryBefore,
            MemoryAfter = memoryAfter,
            ThreadCount = threadCountBefore
        };
    }

    protected void AssertPerformance(PerformanceMetrics metrics, long maxDurationMs, long maxMemoryMb)
    {
        Assert.True(
            metrics.ElapsedMilliseconds <= maxDurationMs,
            $"Operation took {metrics.ElapsedMilliseconds}ms, expected max {maxDurationMs}ms");

        var memoryMb = metrics.MemoryAllocated / (1024 * 1024);
        Assert.True(
            memoryMb <= maxMemoryMb,
            $"Operation allocated {memoryMb}MB, expected max {maxMemoryMb}MB");
    }

    public async Task InitializeAsync()
    {
        HttpClient = new HttpClient { BaseAddress = new Uri(BaseUrl) };
        await Task.CompletedTask;
    }

    public async Task DisposeAsync()
    {
        HttpClient?.Dispose();
        await Task.CompletedTask;
    }
}
```

### Integration Performance Tests

```csharp
using System.Net.Http;
using System.Threading.Tasks;
using Xunit;

namespace BookRatings.Performance.Integration.Tests;

public class BookServicePerformanceTests : PerformanceTestBase
{
    [Fact]
    public async Task GetBooks_Should_Complete_Under_200ms()
    {
        var metrics = await MeasureAsync(async () =>
        {
            var response = await HttpClient.GetAsync("/api/books?skip=0&take=10");
            Assert.True(response.IsSuccessStatusCode);
        });

        AssertPerformance(metrics, maxDurationMs: 200, maxMemoryMb: 10);
    }

    [Fact]
    public async Task GetBooks_Concurrent_Requests()
    {
        const int concurrentRequests = 100;
        var tasks = Enumerable.Range(0, concurrentRequests)
            .Select(i => HttpClient.GetAsync("/api/books"))
            .ToList();

        var metrics = await MeasureAsync(async () =>
        {
            await Task.WhenAll(tasks);
        });

        var responses = await Task.WhenAll(tasks);
        Assert.All(responses, r => Assert.True(r.IsSuccessStatusCode));
        AssertPerformance(metrics, maxDurationMs: 5000, maxMemoryMb: 50);
    }

    [Theory]
    [InlineData(10)]
    [InlineData(100)]
    [InlineData(1000)]
    public async Task GetBooks_Pagination_Performance(int take)
    {
        var metrics = await MeasureAsync(async () =>
        {
            var response = await HttpClient.GetAsync($"/api/books?skip=0&take={take}");
            Assert.True(response.IsSuccessStatusCode);
        });

        var expectedDurationMs = take switch
        {
            10 => 150,
            100 => 300,
            1000 => 500,
            _ => 1000
        };

        AssertPerformance(metrics, maxDurationMs: expectedDurationMs, maxMemoryMb: 20);
    }

    [Fact]
    public async Task CreateBook_Performance()
    {
        var payload = new StringContent(
            @"{""title"":""Perf Test Book"",""author"":""Test Author""}",
            System.Text.Encoding.UTF8,
            "application/json");

        var metrics = await MeasureAsync(async () =>
        {
            var response = await HttpClient.PostAsync("/api/books", payload);
            Assert.True(response.IsSuccessStatusCode);
        });

        AssertPerformance(metrics, maxDurationMs: 300, maxMemoryMb: 15);
    }
}
```

## Performance Thresholds & SLAs

**Metrics/thresholds.json**

```json
{
  "response_times": {
    "books_list": {
      "p50": 100,
      "p95": 300,
      "p99": 500,
      "unit": "ms"
    },
    "ratings_submit": {
      "p50": 200,
      "p95": 500,
      "p99": 1000,
      "unit": "ms"
    },
    "search": {
      "p50": 150,
      "p95": 400,
      "p99": 800,
      "unit": "ms"
    }
  },
  "error_rates": {
    "acceptable": 0.001,
    "warning": 0.005,
    "critical": 0.01
  },
  "throughput": {
    "requests_per_second": 1000,
    "concurrent_users": 500
  },
  "resource_utilization": {
    "cpu_limit": 80,
    "memory_limit": 85,
    "disk_io_limit": 90
  }
}
```

## Performance Reporting

### Test Results Analysis Script

**Scripts/analyze-results.sh**

```bash
#!/bin/bash

set -e

RESULTS_DIR="Testing/Performance/Results"
REPORT_FILE="$RESULTS_DIR/performance-report.json"
HTML_REPORT="$RESULTS_DIR/performance-report.html"

echo "📊 Analyzing performance test results..."

# Parse k6 results
if [ -f "$RESULTS_DIR/k6-output.json" ]; then
    echo "Analyzing k6 load test results..."
    
    # Extract key metrics
    cat "$RESULTS_DIR/k6-output.json" | jq '{
        total_requests: .metrics.requests.total,
        failed_requests: .metrics.requests.failed,
        error_rate: .metrics.error_rate.rate,
        p95_duration: .metrics.http_req_duration.p95,
        p99_duration: .metrics.http_req_duration.p99,
        max_duration: .metrics.http_req_duration.max
    }' > "$REPORT_FILE"
    
    echo "✅ K6 results parsed"
fi

# Compare with baseline
if [ -f "$RESULTS_DIR/baseline-metrics.json" ]; then
    echo "Comparing with baseline..."
    
    CURRENT_P95=$(jq '.p95_duration' "$REPORT_FILE")
    BASELINE_P95=$(jq '.p95_duration' "$RESULTS_DIR/baseline-metrics.json")
    
    if (( $(echo "$CURRENT_P95 > $BASELINE_P95 * 1.2" | bc -l) )); then
        echo "⚠️  P95 latency increased by more than 20%"
        echo "Current: ${CURRENT_P95}ms, Baseline: ${BASELINE_P95}ms"
    else
        echo "✅ Performance within acceptable range"
    fi
fi

echo "✅ Analysis complete!"
```

### HTML Report Generation

```bash
#!/bin/bash

# Generate HTML report with charts
k6 run --out html=results/report.html scripts/smoke-test.js

# Convert benchmark results to HTML
dotnet run -c Release -p Testing/Performance/BookRatings.Performance.Tests/ \
  --exportjson=results/benchmarks.json

# Merge reports
python3 Scripts/merge-reports.py \
  --k6 results/k6-output.json \
  --benchmark results/benchmarks.json \
  --output results/performance-report.html
```

## CI/CD Integration

### GitHub Actions Performance Testing

**.github/workflows/performance-test.yml**

```yaml
name: Performance Testing

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  load-testing:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Start services
        run: |
          docker-compose -f Deployment/podman/docker-compose.yml up -d
          sleep 30
      
      - name: Install k6
        run: |
          sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
          echo "deb https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6-stable.list
          sudo apt-get update && sudo apt-get install k6
      
      - name: Run smoke test
        run: k6 run --out json=results/smoke-test.json Testing/Performance/LoadTesting/k6/scripts/smoke-test.js
      
      - name: Run load test
        run: k6 run -c Testing/Performance/LoadTesting/k6/config/load.json --out json=results/load-test.json Testing/Performance/LoadTesting/k6/scripts/books-api.js
      
      - name: Analyze results
        run: bash Testing/Performance/Scripts/analyze-results.sh
      
      - name: Compare with baseline
        run: bash Testing/Performance/Scripts/compare-baselines.sh
      
      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: performance-test-results
          path: results/

  benchmark-testing:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      
      - name: Run benchmarks
        run: dotnet run -c Release -p Testing/Performance/BookRatings.Performance.Tests/
      
      - name: Upload benchmark results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: Testing/Performance/BookRatings.Performance.Tests/BenchmarkDotNet.Artifacts/

  performance-regression-check:
    runs-on: ubuntu-latest
    needs: [load-testing, benchmark-testing]
    
    steps:
      - uses: actions/download-artifact@v3
        with:
          name: performance-test-results
      
      - name: Check for regressions
        run: |
          # Compare metrics against thresholds
          python3 scripts/check-regression.py \
            --results results/ \
            --thresholds Testing/Performance/Metrics/thresholds.json
      
      - name: Notify on regression
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "❌ Performance regression detected",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Performance Regression Alert*\nSee GitHub Actions for details"
                  }
                }
              ]
            }
```

## Best Practices

### Load Test Planning

1. **Identify Critical Paths**: Focus on high-traffic endpoints
2. **Set Realistic Workloads**: Match production traffic patterns
3. **Gradual Ramp-Up**: Avoid sudden spikes
4. **Multiple Scenarios**: Smoke, load, stress, spike tests
5. **Measure Everything**: Latency, throughput, errors, resource usage
6. **Baseline Comparison**: Compare against known good performance
7. **Monitor Infrastructure**: CPU, memory, disk I/O, network

### Benchmark Best Practices

1. **Warm-Up**: Run warm-up iterations before measurements
2. **Multiple Runs**: Execute multiple times for statistical accuracy
3. **Measure What Matters**: Focus on hot paths
4. **Use Memory Diagnostics**: Track allocations
5. **Test Both Scenarios**: Single-threaded and concurrent
6. **Document Assumptions**: Include seed data, cache state
7. **Track Over Time**: Compare benchmark results across versions

## Interpreting Results

### Key Metrics

```
Latency (Response Time):
- P50 (median): 50% of requests below this time
- P95: 95% of requests below this time
- P99: 99% of requests below this time
- Max: Slowest request

Throughput:
- Requests Per Second (RPS)
- Transactions Per Second (TPS)

Errors:
- Error Rate: % of failed requests
- Error Types: Timeouts, 5xx errors, connection issues

Resource Usage:
- CPU %: Processor utilization
- Memory MB: RAM consumption
- GC Collections: Garbage collection events
```

### Acceptable Thresholds

```
Response Times:
✅ P95 < 500ms  - Excellent
⚠️  P95 < 1s    - Good
❌ P95 > 2s     - Needs optimization

Error Rate:
✅ < 0.1%       - Excellent
⚠️  < 1%        - Acceptable
❌ > 5%         - Critical

CPU Usage:
✅ < 70%        - Normal
⚠️  70-85%      - Watch carefully
❌ > 90%        - Overloaded
```

## Troubleshooting Performance Issues

### High Latency
- Check database query performance
- Review N+1 query problems
- Analyze cache hit rates
- Monitor network latency

### Memory Leaks
- Review GC collections
- Check for circular references
- Analyze large object heap
- Monitor handles/connections

### High CPU
- Profile hot paths
- Reduce synchronous operations
- Optimize algorithms
- Consider caching

### High Error Rate
- Check timeout configurations
- Review failure logs
- Monitor upstream services
- Verify resource availability

---

**References**:
- [k6 Documentation](https://k6.io/docs/)
- [BenchmarkDotNet](https://benchmarkdotnet.org/)
- [JMeter User Guide](https://jmeter.apache.org/usermanual/)
- [Locust Documentation](https://locust.io/)
