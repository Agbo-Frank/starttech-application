#!/usr/bin/env bash
# Deploy frontend build to S3 and invalidate CloudFront cache.
# Usage: ./scripts/deploy-frontend.sh
# Requires: S3_BUCKET_NAME, CLOUDFRONT_DISTRIBUTION_ID, AWS credentials

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/../Client/dist"

if [[ ! -d "$DIST_DIR" ]]; then
  echo "ERROR: Build directory not found at $DIST_DIR"
  echo "Run 'npm run build' from the Client directory first."
  exit 1
fi

: "${S3_BUCKET_NAME:?S3_BUCKET_NAME is required}"
: "${CLOUDFRONT_DISTRIBUTION_ID:?CLOUDFRONT_DISTRIBUTION_ID is required}"

echo "=== Syncing static assets to S3 (immutable cache) ==="
aws s3 sync "$DIST_DIR" "s3://$S3_BUCKET_NAME" \
  --delete \
  --exclude "index.html" \
  --cache-control "public,max-age=31536000,immutable"

echo "=== Uploading index.html (no-cache) ==="
aws s3 cp "$DIST_DIR/index.html" "s3://$S3_BUCKET_NAME/index.html" \
  --cache-control "no-cache,no-store,must-revalidate" \
  --content-type "text/html"

echo "=== Creating CloudFront invalidation ==="
INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
  --paths "/*" \
  --query Invalidation.Id \
  --output text)
echo "Invalidation ID: $INVALIDATION_ID"

echo "=== Waiting for invalidation to complete ==="
aws cloudfront wait invalidation-completed \
  --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
  --id "$INVALIDATION_ID"

echo "=== Frontend deployment complete ==="
