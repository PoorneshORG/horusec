#!/bin/bash
set -e

# Input arguments
DOJO_URL=$1
DOJO_API_KEY=$2
PRODUCT_NAME=$3
SCAN_FILE=$4
ENGAGEMENT_NAME=$5
# Default TEST_TITLE to repo-branch if not provided
TEST_TITLE=${6:-"${GITHUB_REPOSITORY##*/}-${GITHUB_REF##*/}"}

# Validation
if [ -z "$DOJO_URL" ] || [ -z "$DOJO_API_KEY" ] || [ -z "$PRODUCT_NAME" ] || [ -z "$SCAN_FILE" ] || [ -z "$ENGAGEMENT_NAME" ]; then
  echo "Usage: $0 <DOJO_URL> <DOJO_API_KEY> <PRODUCT_NAME> <SCAN_FILE> <ENGAGEMENT_NAME> [TEST_TITLE]"
  exit 1
fi

if [ ! -f "$SCAN_FILE" ]; then
  echo "❌ Scan file $SCAN_FILE not found!"
  exit 1
fi

DATE=$(date +%F)
AUTH_HEADER="Authorization: Token $DOJO_API_KEY"

echo "📤 Uploading $SCAN_FILE to existing DefectDojo product='$PRODUCT_NAME', engagement='$ENGAGEMENT_NAME'..."

curl -s -X POST "$DOJO_URL/api/v2/reimport-scan/" \
  -H "$AUTH_HEADER" \
  -F "scan_date=$DATE" \
  -F "scan_type=Gitleaks Scan" \
  -F "active=true" \
  -F "verified=true" \
  -F "product_name=$PRODUCT_NAME" \
  -F "engagement_name=$ENGAGEMENT_NAME" \
  -F "test_title=$TEST_TITLE - $DATE" \
  -F "auto_create_context=true" \
  -F "deduplication_on_engagement=true" \
  -F "close_old_findings=true" \
  -F "engagement_end_date=$(date -d '+365 days' +%F)" \
  -F "file=@$SCAN_FILE"

echo "✅ Upload complete!"
