# starttech-application

Full-stack Todo application with a React frontend and Go backend API.

## Stack

| Component | Technology | Deployment |
|---|---|---|
| Frontend | React + Vite + TypeScript | AWS S3 + CloudFront |
| Backend API | Go (Gin) | AWS EC2 (ASG) behind ALB |
| Cache | Redis | AWS ElastiCache |
| Database | MongoDB | MongoDB Atlas |

## Repository Structure

```
starttech-application/
├── .github/workflows/
│   ├── backend-ci-cd.yml       # Test → Docker build → ECR → rolling EC2 deploy
│   └── frontend-ci-cd.yml      # Build → S3 sync → CloudFront invalidation
├── Client/                     # React frontend (Vite + TypeScript)
│   ├── src/
│   └── package.json
├── Server/MuchToDo/            # Go backend API
│   ├── cmd/api/main.go
│   ├── internal/
│   ├── Dockerfile              # (used by k8s setup)
│   └── Makefile
├── Dockerfile                  # Root Dockerfile (built from repo root, used by CI/CD)
├── scripts/
│   ├── deploy-frontend.sh
│   ├── deploy-backend.sh
│   ├── health-check.sh
│   └── rollback.sh
└── RUNBOOK.md
```

## Local Development

### Backend

```bash
cd Server/MuchToDo

# Copy and configure env
cp .env.example .env
# Edit .env: set MONGO_URI, JWT_SECRET_KEY, REDIS_ADDR

# Run with Docker Compose (starts API + MongoDB + Redis)
make dc-up

# Or run directly (requires local MongoDB and Redis)
make run
```

The API will be available at `http://localhost:8080`. Health check: `GET /ping`.

### Frontend

```bash
cd Client
npm install

# Set backend URL
echo "VITE_API_BASE_URL=http://localhost:8080" > .env.local

npm run dev
# Available at http://localhost:5173
```

## Environment Variables

### Backend (`Server/MuchToDo/.env`)

| Variable | Description | Default |
|---|---|---|
| `PORT` | Server port | `8080` |
| `MONGO_URI` | MongoDB Atlas connection string | — |
| `DB_NAME` | Database name | `much_todo_db` |
| `JWT_SECRET_KEY` | JWT signing secret | — |
| `JWT_EXPIRATION_HOURS` | JWT token lifetime | `72` |
| `ENABLE_CACHE` | Enable Redis cache | `false` |
| `REDIS_ADDR` | Redis address (`host:port`) | — |
| `LOG_LEVEL` | Log level (`INFO`, `DEBUG`) | `INFO` |
| `LOG_FORMAT` | Log format (`json`, `text`) | `json` |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins | `http://localhost:5173` |
| `SECURE_COOKIE` | Use Secure flag on cookies | `false` |

### Frontend (`.env.local` or CI secret)

| Variable | Description |
|---|---|
| `VITE_API_BASE_URL` | Backend API base URL (baked into JS bundle at build time) |

## GitHub Secrets Required

Set these in the `starttech-application` GitHub repository settings:

| Secret | Value (from `terraform output`) |
|---|---|
| `AWS_ACCESS_KEY_ID` | IAM access key |
| `AWS_SECRET_ACCESS_KEY` | IAM secret key |
| `AWS_REGION` | `us-east-1` |
| `AWS_ACCOUNT_ID` | `aws sts get-caller-identity --query Account --output text` |
| `ECR_REPOSITORY_NAME` | `terraform output -raw ecr_repository_name` |
| `S3_BUCKET_NAME` | `terraform output -raw s3_bucket_name` |
| `CLOUDFRONT_DISTRIBUTION_ID` | `terraform output -raw cloudfront_distribution_id` |
| `ALB_DNS_NAME` | `terraform output -raw alb_dns_name` |
| `VITE_API_BASE_URL` | `http://$(terraform output -raw alb_dns_name)` |

## CI/CD Pipelines

### Backend (`backend-ci-cd.yml`)

Triggered by changes to `Server/**` or `Dockerfile`.

1. **test** – unit tests (`go test ./...`), integration tests (`-tags=integration`), golangci-lint, govulncheck
2. **build-and-push** – Docker build (from repo root), Trivy CRITICAL scan, push `:<git-sha>` and `:latest` to ECR
3. **deploy-backend** – ASG instance refresh (rolling, 50% min healthy), poll until complete, `/ping` smoke test

### Frontend (`frontend-ci-cd.yml`)

Triggered by changes to `Client/**`.

1. **test-and-build** – `npm ci`, `npm run lint`, `npm audit --audit-level=high`, `npm run build`
2. **deploy-frontend** – S3 sync (immutable cache for assets, no-cache for `index.html`), CloudFront invalidation

## Manual Deployment

```bash
# Backend
export ASG_NAME=starttech-backend-asg
./scripts/deploy-backend.sh

# Frontend (build first)
cd Client && npm run build && cd ..
export S3_BUCKET_NAME=<bucket>
export CLOUDFRONT_DISTRIBUTION_ID=<id>
./scripts/deploy-frontend.sh

# Health check
export ALB_DNS_NAME=<alb-dns>
./scripts/health-check.sh $ALB_DNS_NAME

# Rollback
export ECR_REPOSITORY_NAME=starttech-backend
export AWS_REGION=us-east-1
./scripts/rollback.sh <previous-git-sha>
```
