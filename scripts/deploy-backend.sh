#!/usr/bin/env bash
# Trigger a rolling deploy of the backend via ASG instance refresh.
# New instances will pull the latest Docker image from ECR on startup.
# Usage: ./scripts/deploy-backend.sh [asg-name]
# Requires: AWS credentials with autoscaling permissions

set -euo pipefail

ASG_NAME="${1:-${ASG_NAME:-starttech-backend-asg}}"

echo "=== Triggering rolling deploy for ASG: $ASG_NAME ==="

REFRESH_ID=$(aws autoscaling start-instance-refresh \
  --auto-scaling-group-name "$ASG_NAME" \
  --strategy Rolling \
  --preferences MinHealthyPercentage=50,InstanceWarmup=120 \
  --query InstanceRefreshId \
  --output text)

echo "Instance refresh started: $REFRESH_ID"
echo ""
echo "To monitor progress:"
echo "  aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME"
echo ""
echo "Or run the health check once deploy completes:"
echo "  ./scripts/health-check.sh \$ALB_DNS_NAME"
