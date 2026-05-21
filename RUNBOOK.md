# Runbook – StartTech Application

## Backend Troubleshooting

### Container not starting on EC2

```bash
# Connect via SSM Session Manager (no SSH needed)
aws ssm start-session --target <instance-id>

# Check container status
docker ps -a

# Check user-data log
cat /var/log/user-data.log

# Check container logs
docker logs muchtodo-api --tail 100

# Restart container manually
docker restart muchtodo-api
```

### Backend returns 500 errors

```bash
# Tail live logs in CloudWatch
aws logs tail /starttech/backend/application --follow --format short

# Check MongoDB connectivity
# Look for lines like: "database":"down" in /health response
curl http://<alb-dns>/health
```

### Frontend shows blank page or 404

1. Check `index.html` was uploaded to S3:
   ```bash
   aws s3 ls s3://<bucket-name>/index.html
   ```

2. Verify CloudFront has custom error responses for 403/404 → `index.html` (configured in Terraform)

3. Force a CloudFront cache refresh:
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id <dist-id> \
     --paths "/*"
   ```

### CORS errors in browser console

The backend `ALLOWED_ORIGINS` env var must include the CloudFront domain.
It is set in the EC2 user-data script via SSM parameter `/starttech/prod/CLOUDFRONT_DOMAIN`.

If you need to update it without a full instance refresh:
```bash
# Update SSM param
aws ssm put-parameter \
  --name /starttech/prod/CLOUDFRONT_DOMAIN \
  --value "<cloudfront-domain.cloudfront.net>" \
  --overwrite

# Restart container on each instance (or trigger instance refresh)
aws ssm start-session --target <instance-id>
# Then:
docker stop muchtodo-api && docker start muchtodo-api
```

## Testing

### Run backend tests locally

```bash
cd Server/MuchToDo

# Unit tests (no external dependencies needed)
go test -v ./...

# Integration tests (requires Docker daemon running — uses testcontainers)
INTEGRATION=true go test -tags=integration -v ./...
```

### Run frontend lint locally

```bash
cd Client
npm ci
npm run lint
npm audit --audit-level=high
```

## Useful Health Endpoints

| Endpoint | Description |
|---|---|
| `GET /ping` | Liveness – returns `{"message":"pong"}` |
| `GET /health` | Readiness – checks MongoDB and Redis connectivity |
| `GET /api/v1/docs/index.html` | Swagger API documentation |
