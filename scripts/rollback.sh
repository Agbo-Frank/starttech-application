#!/usr/bin/env bash
# Roll back the backend by re-tagging a previous ECR image as :latest,
# then triggering an ASG instance refresh.
# Usage: ./scripts/rollback.sh <previous-git-sha>
# Requires: ECR_REPOSITORY_NAME, AWS_REGION, AWS credentials

set -euo pipefail

ROLLBACK_TAG="${1:?Usage: rollback.sh <previous-git-sha>}"
: "${ECR_REPOSITORY_NAME:?ECR_REPOSITORY_NAME is required}"
: "${AWS_REGION:?AWS_REGION is required}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
REPO="${ECR_REGISTRY}/${ECR_REPOSITORY_NAME}"

echo "=== Rolling back to image tag: $ROLLBACK_TAG ==="

# Fetch the manifest of the rollback image
MANIFEST=$(aws ecr batch-get-image \
  --repository-name "$ECR_REPOSITORY_NAME" \
  --image-ids imageTag="$ROLLBACK_TAG" \
  --query 'images[0].imageManifest' \
  --output text \
  --region "$AWS_REGION")

if [[ -z "$MANIFEST" || "$MANIFEST" == "None" ]]; then
  echo "ERROR: Image with tag '$ROLLBACK_TAG' not found in ECR repo '$ECR_REPOSITORY_NAME'"
  exit 1
fi

# Re-tag the rollback image as :latest
aws ecr put-image \
  --repository-name "$ECR_REPOSITORY_NAME" \
  --image-tag latest \
  --image-manifest "$MANIFEST" \
  --region "$AWS_REGION"

echo "Successfully tagged $ROLLBACK_TAG as :latest in ECR"

# Trigger rolling deploy
echo ""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SCRIPT_DIR/deploy-backend.sh"
