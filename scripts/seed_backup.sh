#!/usr/bin/env bash
# Upload sample backup files to the S3 bucket to demonstrate the system.
# Usage: ./scripts/seed_backup.sh <bucket_name>

set -euo pipefail

BUCKET="${1:?Usage: $0 <bucket_name>}"
DATE=$(date -u +%Y-%m-%d)

echo "Seeding backup bucket ${BUCKET}..."

# Database backup snapshot
echo '{"type":"db_snapshot","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","records":4821,"size_mb":12}' \
  | aws s3 cp - "s3://${BUCKET}/db/${DATE}/snapshot.json" --content-type "application/json"

# Application config backup
echo '{"type":"app_config","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","version":"1.4.2","env":"prod"}' \
  | aws s3 cp - "s3://${BUCKET}/config/${DATE}/app-config.json" --content-type "application/json"

# Simulate an update to trigger versioning
echo '{"type":"db_snapshot","timestamp":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","records":4830,"size_mb":12,"note":"incremental update"}' \
  | aws s3 cp - "s3://${BUCKET}/db/${DATE}/snapshot.json" --content-type "application/json"

echo ""
echo "Done. Objects in ${BUCKET}:"
aws s3api list-objects-v2 \
  --bucket "$BUCKET" \
  --query "Contents[].{Key:Key,Size:Size}" \
  --output table

echo ""
echo "Versions for db/${DATE}/snapshot.json:"
aws s3api list-object-versions \
  --bucket "$BUCKET" \
  --prefix "db/${DATE}/snapshot.json" \
  --query "Versions[].{Key:Key,VersionId:VersionId,IsLatest:IsLatest}" \
  --output table
