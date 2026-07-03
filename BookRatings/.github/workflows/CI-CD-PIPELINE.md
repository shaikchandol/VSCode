# GitHub Actions CI/CD Pipeline

## Overview

Automated CI/CD pipeline for building, testing, scanning, and deploying BookRatings microservices to any cloud (Azure, AWS, GCP) with conditional deployment logic.

## Project Structure

```
.github/
├── workflows/
│   ├── ci.yml                           # Main CI pipeline (build, test, scan)
│   ├── cd-azure.yml                     # Azure deployment
│   ├── cd-aws.yml                       # AWS deployment
│   ├── cd-gcp.yml                       # GCP deployment
│   ├── security-scan.yml                # SAST/DAST scanning
│   ├── dependency-check.yml             # Dependency vulnerability scanning
│   ├── container-scan.yml               # Container image scanning
│   ├── performance-test.yml             # Load/performance testing
│   ├── integration-test.yml             # Integration tests with Podman
│   └── promote-release.yml              # Release promotion workflow
│
├── actions/
│   ├── setup-environment/action.yml     # Custom action: Setup build environment
│   ├── build-service/action.yml         # Custom action: Build service
│   ├── scan-code/action.yml             # Custom action: SAST scanning
│   └── deploy-service/action.yml        # Custom action: Deploy to cloud
│
└── dependabot.yml                       # Automated dependency updates
```

## Main CI Pipeline (ci.yml)

```yaml
name: CI Pipeline

on:
  push:
    branches: [ main, develop, release/** ]
    paths:
      - 'Services/**'
      - 'Gateway/**'
      - 'Clients/**'
      - 'Shared/**'
      - '.github/workflows/**'
  pull_request:
    branches: [ main, develop ]
  schedule:
    - cron: '0 2 * * *'  # Daily security scan at 2 AM

env:
  REGISTRY: ghcr.io
  DOTNET_VERSION: '10.0.x'

jobs:
  setup:
    name: Setup & Determine Services
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.detect.outputs.services }}
      version: ${{ steps.version.outputs.version }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect changed services
        id: detect
        run: |
          # Detect which services changed
          if [[ "${{ github.event_name }}" == "pull_request" ]]; then
            CHANGED_FILES=$(git diff --name-only origin/${{ github.base_ref }})
          else
            CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r ${{ github.sha }})
          fi
          
          SERVICES='[]'
          [[ $CHANGED_FILES == *"Services/Books"* ]] && SERVICES=$(echo $SERVICES | jq '. += ["books"]')
          [[ $CHANGED_FILES == *"Services/Ratings"* ]] && SERVICES=$(echo $SERVICES | jq '. += ["ratings"]')
          [[ $CHANGED_FILES == *"Services/Users"* ]] && SERVICES=$(echo $SERVICES | jq '. += ["users"]')
          [[ $CHANGED_FILES == *"Services/Admin"* ]] && SERVICES=$(echo $SERVICES | jq '. += ["admin"]')
          [[ $CHANGED_FILES == *"Services/Reporting"* ]] && SERVICES=$(echo $SERVICES | jq '. += ["reporting"]')
          [[ $CHANGED_FILES == *"Gateway"* ]] && SERVICES=$(echo $SERVICES | jq '. += ["gateway"]')
          
          echo "services=$SERVICES" >> $GITHUB_OUTPUT

      - name: Generate version
        id: version
        run: |
          VERSION="1.0.0-$(date +%Y%m%d).${{ github.run_number }}"
          echo "version=$VERSION" >> $GITHUB_OUTPUT

  build:
    name: Build & Test
    needs: setup
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.setup.outputs.services) }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Restore dependencies
        run: |
          dotnet restore Services/${{ matrix.service }}/

      - name: Build
        run: |
          dotnet build Services/${{ matrix.service }}/ \
            -c Release \
            -p:Version=${{ needs.setup.outputs.version }} \
            --no-restore

      - name: Unit Tests
        run: |
          dotnet test Services/${{ matrix.service }}/BookRatings.Services.${{ matrix.service }}.Tests/ \
            -c Release \
            --no-build \
            --filter "Category=Unit" \
            --logger "trx;LogFileName=test-results.trx" \
            /p:CollectCoverageMetrics=true

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: '**/coverage.opencover.xml'
          flags: ${{ matrix.service }}
          fail_ci_if_error: false

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results-${{ matrix.service }}
          path: '**/test-results.trx'

  integration-tests:
    name: Integration Tests
    needs: [ setup, build ]
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.setup.outputs.services) }}
    services:
      sqlserver:
        image: mcr.microsoft.com/mssql/server:2022-latest
        env:
          SA_PASSWORD: YourPassword123!
          ACCEPT_EULA: "Y"
        options: >-
          --health-cmd="/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P YourPassword123! -Q 'SELECT 1'"
          --health-interval=10s
          --health-timeout=3s
          --health-retries=5
        ports:
          - 1433:1433

      rabbitmq:
        image: rabbitmq:3.12-management-alpine
        options: >-
          --health-cmd="rabbitmq-diagnostics -q ping"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=5
        ports:
          - 5672:5672

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd="redis-cli ping"
          --health-interval=10s
          --health-timeout=3s
          --health-retries=5
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ env.DOTNET_VERSION }}

      - name: Integration Tests
        env:
          SQLSERVER_CONNECTION: "Server=localhost,1433;User Id=sa;Password=YourPassword123!;"
          RABBITMQ_HOST: "localhost"
          REDIS_CONNECTION: "localhost:6379"
        run: |
          dotnet test Services/${{ matrix.service }}/BookRatings.Services.${{ matrix.service }}.Tests/ \
            -c Release \
            --filter "Category=Integration" \
            --logger "trx;LogFileName=integration-test-results.trx"

      - name: Upload integration test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: integration-test-results-${{ matrix.service }}
          path: '**/integration-test-results.trx'

  sast-scan:
    name: SAST Security Scan
    needs: [ setup, build ]
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.setup.outputs.services) }}
    steps:
      - uses: actions/checkout@v4

      - name: Run Sonarqube analysis
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        with:
          args: >-
            -Dsonar.sources=Services/${{ matrix.service }}/
            -Dsonar.projectKey=bookratings_${{ matrix.service }}
            -Dsonar.organization=bookratings

      - name: Run Trivy file scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: 'Services/${{ matrix.service }}'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

  container-build:
    name: Build Container Images
    needs: [ setup, build, integration-tests, sast-scan ]
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.setup.outputs.services) }}
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Log in to Container Registry
        uses: docker/login-action@v2
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ${{ env.REGISTRY }}/${{ github.repository_owner }}/${{ matrix.service }}-service
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}},value=${{ needs.setup.outputs.version }}
            type=sha,prefix={{branch}}-

      - name: Build and push image
        uses: docker/build-push-action@v4
        with:
          context: Services/${{ matrix.service }}/
          file: Services/${{ matrix.service }}/Dockerfile
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  container-scan:
    name: Container Image Security Scan
    needs: [ setup, container-build ]
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.setup.outputs.services) }}
    steps:
      - name: Run Trivy vulnerability scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ github.repository_owner }}/${{ matrix.service }}-service:${{ needs.setup.outputs.version }}
          format: 'sarif'
          output: 'trivy-container-results.sarif'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-container-results.sarif'

  dependency-check:
    name: Dependency Vulnerability Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run NuGet security audit
        run: |
          dotnet list package --vulnerable 2>&1 | tee audit-results.txt
          if grep -q "has .*vulnerabilities" audit-results.txt; then
            echo "❌ Vulnerable dependencies found"
            exit 1
          fi

  quality-gate:
    name: Quality Gate
    needs: [ build, integration-tests, sast-scan, container-scan ]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Check build status
        if: ${{ needs.build.result != 'success' }}
        run: exit 1

      - name: Check test status
        if: ${{ needs.integration-tests.result != 'success' }}
        run: exit 1

      - name: Check security scan status
        if: ${{ needs.sast-scan.result != 'success' }}
        run: exit 1

      - name: ✅ Quality gate passed
        run: echo "All checks passed!"

  notify:
    name: Notify Results
    needs: [ setup, quality-gate ]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Slack notification
        uses: slackapi/slack-github-action@v1
        if: always()
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "BookRatings CI Pipeline: ${{ job.status }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*BookRatings CI Pipeline*\nVersion: ${{ needs.setup.outputs.version }}\nStatus: ${{ job.status }}"
                  }
                }
              ]
            }
```

## Azure Deployment (cd-azure.yml)

```yaml
name: Deploy to Azure

on:
  workflow_run:
    workflows: ["CI Pipeline"]
    types: [completed]
    branches: [main, develop]

env:
  REGISTRY: ghcr.io
  AZURE_RESOURCE_GROUP: bookratings-prod
  AZURE_REGISTRY_LOGIN_SERVER: bookratings.azurecr.io
  AKS_CLUSTER_NAME: bookratings-aks

jobs:
  deploy-azure:
    name: Deploy to Azure AKS
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    strategy:
      matrix:
        service: [books, ratings, users, admin, reporting, gateway]
    steps:
      - uses: actions/checkout@v4

      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Get AKS context
        run: |
          az aks get-credentials \
            --resource-group ${{ env.AZURE_RESOURCE_GROUP }} \
            --name ${{ env.AKS_CLUSTER_NAME }} \
            --overwrite-existing

      - name: Deploy to AKS
        run: |
          kubectl set image deployment/${{ matrix.service }}-service \
            ${{ matrix.service }}-service=${{ env.AZURE_REGISTRY_LOGIN_SERVER }}/${{ matrix.service }}-service:${{ github.sha }} \
            -n bookratings || \
          kubectl apply -f k8s/${{ matrix.service }}-deployment.yaml

      - name: Verify deployment
        run: |
          kubectl rollout status deployment/${{ matrix.service }}-service -n bookratings --timeout=5m

      - name: Run smoke tests
        run: |
          kubectl run smoke-test-${{ matrix.service }} \
            --image=${{ env.REGISTRY }}/${{ github.repository_owner }}/${{ matrix.service }}-service:${{ github.sha }} \
            --restart=Never \
            -n bookratings
```

## AWS Deployment (cd-aws.yml)

```yaml
name: Deploy to AWS

on:
  workflow_run:
    workflows: ["CI Pipeline"]
    types: [completed]
    branches: [main, develop]

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
  ECS_CLUSTER_NAME: bookratings-ecs

jobs:
  deploy-aws:
    name: Deploy to AWS ECS
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    strategy:
      matrix:
        service: [books, ratings, users, admin, reporting, gateway]
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to ECR
        run: |
          aws ecr get-login-password --region ${{ env.AWS_REGION }} | \
          docker login --username AWS --password-stdin ${{ env.ECR_REGISTRY }}

      - name: Push image to ECR
        run: |
          docker pull ghcr.io/${{ github.repository_owner }}/${{ matrix.service }}-service:${{ github.sha }}
          docker tag ghcr.io/${{ github.repository_owner }}/${{ matrix.service }}-service:${{ github.sha }} \
            ${{ env.ECR_REGISTRY }}/${{ matrix.service }}-service:${{ github.sha }}
          docker push ${{ env.ECR_REGISTRY }}/${{ matrix.service }}-service:${{ github.sha }}

      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster ${{ env.ECS_CLUSTER_NAME }} \
            --service ${{ matrix.service }}-service \
            --force-new-deployment \
            --region ${{ env.AWS_REGION }}

      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster ${{ env.ECS_CLUSTER_NAME }} \
            --services ${{ matrix.service }}-service \
            --region ${{ env.AWS_REGION }}
```

## GCP Deployment (cd-gcp.yml)

```yaml
name: Deploy to GCP

on:
  workflow_run:
    workflows: ["CI Pipeline"]
    types: [completed]
    branches: [main, develop]

env:
  GCP_PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  GCP_REGION: us-central1
  GKE_CLUSTER: bookratings-gke

jobs:
  deploy-gcp:
    name: Deploy to GCP GKE
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    strategy:
      matrix:
        service: [books, ratings, users, admin, reporting, gateway]
    steps:
      - uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Configure Docker authentication
        run: |
          gcloud auth configure-docker gcr.io

      - name: Push image to GCR
        run: |
          docker pull ghcr.io/${{ github.repository_owner }}/${{ matrix.service }}-service:${{ github.sha }}
          docker tag ghcr.io/${{ github.repository_owner }}/${{ matrix.service }}-service:${{ github.sha }} \
            gcr.io/${{ env.GCP_PROJECT_ID }}/${{ matrix.service }}-service:${{ github.sha }}
          docker push gcr.io/${{ env.GCP_PROJECT_ID }}/${{ matrix.service }}-service:${{ github.sha }}

      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials ${{ env.GKE_CLUSTER }} \
            --zone ${{ env.GCP_REGION }} \
            --project ${{ env.GCP_PROJECT_ID }}

      - name: Deploy to GKE
        run: |
          kubectl set image deployment/${{ matrix.service }}-service \
            ${{ matrix.service }}-service=gcr.io/${{ env.GCP_PROJECT_ID }}/${{ matrix.service }}-service:${{ github.sha }} \
            -n bookratings || \
          kubectl apply -f k8s/${{ matrix.service }}-deployment.yaml

      - name: Verify deployment
        run: |
          kubectl rollout status deployment/${{ matrix.service }}-service -n bookratings --timeout=10m
```

## Secrets Configuration

Add these secrets to GitHub repository settings:

```
# Azure
AZURE_CREDENTIALS          # Service principal credentials
AZURE_REGISTRY_LOGIN_SERVER  # ACR login server

# AWS
AWS_ACCESS_KEY_ID         # AWS access key
AWS_SECRET_ACCESS_KEY     # AWS secret key
AWS_ACCOUNT_ID            # AWS account ID

# GCP
GCP_PROJECT_ID            # GCP project ID
GCP_SA_KEY                # GCP service account key (JSON)

# Scanning
SONAR_TOKEN               # Sonarqube token
SLACK_WEBHOOK             # Slack webhook URL

# Container Registry
GITHUB_TOKEN              # GitHub token (auto-provided)
```

## Pipeline Flow

```
┌─────────────────────┐
│   Detect Changed    │
│     Services        │
└──────────┬──────────┘
           │
           ├─→ Build & Unit Test
           │   ├─→ Integration Tests
           │   ├─→ SAST Scan (SonarQube + Trivy)
           │   ├─→ Dependency Check
           │   └─→ Build Container Images
           │       └─→ Container Security Scan
           │
           └─→ Quality Gate (All checks must pass)
               │
               ├─→ Deploy to Azure (if main branch)
               ├─→ Deploy to AWS (if main branch)
               └─→ Deploy to GCP (if main branch)
                   │
                   └─→ Slack Notification
```

## Conditional Deployment

- **Pull Request**: Build and test only, no deployment
- **Develop Branch**: Deploy to staging environments
- **Main Branch**: Deploy to production (all clouds)
- **Release Branch**: Deploy to production with approval gate
