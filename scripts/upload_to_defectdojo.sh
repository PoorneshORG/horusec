#!/bin/bash

set -e

DOJO_URL="https://vms.anywhere.com"
DOJO_API_KEY="df000989a0da41623dfbb788cf1976ebc86db277"
REPO_NAME=$1
SCAN_FILE=$2
PRODUCT_TYPE_ID=1

DATE=$(date +%F)
ENGAGEMENT_NAME="CI/CD Scan"
TEST_TITLE="Gitleaks Continuous Scan"

AUTH_HEADER="Authorization: Token $DOJO_API_KEY"
JSON_HEADER="Content-Type: application/json"

# 1. Get or create Product
echo "🔍 Checking for Product: $REPO_NAME"
PRODUCT_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/products/?name=$REPO_NAME")
echo "📦 Product lookup response: $PRODUCT_RESPONSE"
PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | jq '.results[0].id')

if [ "$PRODUCT_ID" = "null" ] || [ -z "$PRODUCT_ID" ]; then
  echo "➕ Creating Product: $REPO_NAME"
  CREATE_PRODUCT_RESPONSE=$(curl -s -X POST "$DOJO_URL/api/v2/products/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{\"name\": \"$REPO_NAME\", \"prod_type\": $PRODUCT_TYPE_ID}")
  echo "📦 Create product response: $CREATE_PRODUCT_RESPONSE"
  PRODUCT_ID=$(echo "$CREATE_PRODUCT_RESPONSE" | jq '.id')
fi

echo "✅ Product ID: $PRODUCT_ID"

# 2. Get or create Engagement
echo "🔍 Checking for Engagement: $ENGAGEMENT_NAME"
ENGAGEMENT_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/engagements/?product=$PRODUCT_ID&name=$ENGAGEMENT_NAME")
echo "📂 Engagement lookup response: $ENGAGEMENT_RESPONSE"
ENGAGEMENT_ID=$(echo "$ENGAGEMENT_RESPONSE" | jq '.results[0].id')

if [ "$ENGAGEMENT_ID" = "null" ] || [ -z "$ENGAGEMENT_ID" ]; then
  echo "➕ Creating Engagement: $ENGAGEMENT_NAME"
  CREATE_ENGAGEMENT_RESPONSE=$(curl -s -X POST "$DOJO_URL/api/v2/engagements/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{
          \"product\": $PRODUCT_ID,
          \"name\": \"$ENGAGEMENT_NAME\",
          \"target_start\": \"$DATE\",
          \"target_end\": \"$DATE\",
          \"status\": \"In Progress\",
          \"engagement_type\": \"CI/CD\"
        }")
  echo "📂 Create engagement response: $CREATE_ENGAGEMENT_RESPONSE"
  ENGAGEMENT_ID=$(echo "$CREATE_ENGAGEMENT_RESPONSE" | jq '.id')
fi

echo "✅ Engagement ID: $ENGAGEMENT_ID"

# 3. Get or create Test
echo "🔍 Checking for Test: $TEST_TITLE"
TEST_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/tests/?engagement=$ENGAGEMENT_ID")
TEST_ID=$(echo "$TEST_RESPONSE" | jq ".results[] | select(.title==\"$TEST_TITLE\") | .id")

if [ -z "$TEST_ID" ]; then
  echo "➕ Creating Test: $TEST_TITLE"
  CREATE_TEST_RESPONSE=$(curl -s -X POST "$DOJO_URL/api/v2/tests/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{
          \"engagement\": $ENGAGEMENT_ID,
          \"title\": \"$TEST_TITLE\",
          \"scan_type\": \"Gitleaks Scan\",
          \"target_start\": \"$DATE\",
          \"target_end\": \"$DATE\"
        }")
  echo "🧪 Create test response: $CREATE_TEST_RESPONSE"
  TEST_ID=$(echo "$CREATE_TEST_RESPONSE" | jq '.id')
fi

echo "✅ Test ID: $TEST_ID"

# 4. Upload scan via reimport
echo "📤 Uploading scan to DefectDojo..."
UPLOAD_RESPONSE=$(curl -s -X POST "$DOJO_URL/api/v2/reimport-scan/" \
  -H "$AUTH_HEADER" \
  -F "file=@$SCAN_FILE" \
  -F "scan_type=Gitleaks Scan" \
  -F "engagement=$ENGAGEMENT_ID" \
  -F "test=$TEST_ID" \
  -F "scan_date=$DATE" \
  -F "minimum_severity=Low" \
  -F "active=true" \
  -F "verified=true" \
  -F "close_old_findings=false")

echo "📥 Upload response: $UPLOAD_RESPONSE"
echo "✅ Gitleaks findings uploaded to DefectDojo!"
