#!/bin/bash

set -e

# Input arguments
DOJO_URL=$1
DOJO_API_KEY=$2
REPO_NAME=$3
SCAN_FILE=$4
PRODUCT_TYPE_ID=$5

DATE=$(date +%F)
ENGAGEMENT_NAME="CI/CD Scan"
TEST_TITLE="Gitleaks Continuous Scan"

# Headers
AUTH_HEADER="Authorization: Token $DOJO_API_KEY"
JSON_HEADER="Content-Type: application/json"

# 1. Create or get Product
echo "🔍 Checking for Product: $REPO_NAME"
PRODUCT_ID=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/products/?name=$REPO_NAME" | jq '.results[0].id')

if [ "$PRODUCT_ID" = "null" ] || [ -z "$PRODUCT_ID" ]; then
  echo "➕ Creating Product: $REPO_NAME"
  PRODUCT_ID=$(curl -s -X POST "$DOJO_URL/api/v2/products/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{\"name\": \"$REPO_NAME\", \"prod_type\": $PRODUCT_TYPE_ID}" | jq '.id')
fi

echo "✅ Product ID: $PRODUCT_ID"

# 2. Create or get Engagement
echo "🔍 Checking for Engagement: $ENGAGEMENT_NAME"
ENGAGEMENT_ID=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/engagements/?product=$PRODUCT_ID&name=$ENGAGEMENT_NAME" | jq '.results[0].id')

if [ "$ENGAGEMENT_ID" = "null" ] || [ -z "$ENGAGEMENT_ID" ]; then
  echo "➕ Creating Engagement: $ENGAGEMENT_NAME"
  ENGAGEMENT_ID=$(curl -s -X POST "$DOJO_URL/api/v2/engagements/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{
          \"product\": $PRODUCT_ID,
          \"name\": \"$ENGAGEMENT_NAME\",
          \"target_start\": \"$DATE\",
          \"target_end\": \"$DATE\",
          \"status\": \"In Progress\",
          \"engagement_type\": \"CI/CD\"
        }" | jq '.id')
fi

echo "✅ Engagement ID: $ENGAGEMENT_ID"

# 3. Get or create Test
echo "🔍 Checking for Test: $TEST_TITLE"
TEST_ID=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/tests/?engagement=$ENGAGEMENT_ID" | jq ".results[] | select(.title==\"$TEST_TITLE\") | .id")

if [ -z "$TEST_ID" ]; then
  echo "➕ Creating Test: $TEST_TITLE"
  TEST_ID=$(curl -s -X POST "$DOJO_URL/api/v2/tests/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{
          \"engagement\": $ENGAGEMENT_ID,
          \"title\": \"$TEST_TITLE\",
          \"scan_type\": \"Gitleaks Scan\",
          \"target_start\": \"$DATE\",
          \"target_end\": \"$DATE\"
        }" | jq '.id')
fi

echo "✅ Test ID: $TEST_ID"

# 4. Reimport scan (merge with existing findings)
echo "📤 Reimporting scan to DefectDojo..."
curl -s -X POST "$DOJO_URL/api/v2/reimport-scan/" \
  -H "$AUTH_HEADER" \
  -F "file=@$SCAN_FILE" \
  -F "scan_type=Gitleaks Scan" \
  -F "engagement=$ENGAGEMENT_ID" \
  -F "test=$TEST_ID" \
  -F "scan_date=$DATE" \
  -F "minimum_severity=Low" \
  -F "active=true" \
  -F "verified=true" \
  -F "close_old_findings=false"

echo "✅ Scan uploaded and consolidated!"
