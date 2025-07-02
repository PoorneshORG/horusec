#!/bin/bash
set -e

# Inputs
DOJO_URL=$1
DOJO_API_KEY=$2
PRODUCT_NAME=$3
SCAN_FILE=$4
ENGAGEMENT_NAME=$5
TEST_TITLE=${6:-"Gitleaks Scan"}
PRODUCT_TYPE_NAME=${7:-"CI/CD"}  # Default product type if not given

# Validation
if [ -z "$DOJO_URL" ] || [ -z "$DOJO_API_KEY" ] || [ -z "$PRODUCT_NAME" ] || [ -z "$SCAN_FILE" ] || [ -z "$ENGAGEMENT_NAME" ]; then
  echo "Usage: $0 <DOJO_URL> <DOJO_API_KEY> <PRODUCT_NAME> <SCAN_FILE> <ENGAGEMENT_NAME> [TEST_TITLE] [PRODUCT_TYPE_NAME]"
  exit 1
fi

if [ ! -f "$SCAN_FILE" ]; then
  echo "❌ Scan file $SCAN_FILE not found!"
  exit 1
fi

DATE=$(date +%F)
AUTH_HEADER="Authorization: Token $DOJO_API_KEY"
JSON_HEADER="Content-Type: application/json"

# Step 1: Get or create Product Type ID
echo "🔍 Fetching Product Type ID for '$PRODUCT_TYPE_NAME'"
PRODUCT_TYPE_ID=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/product_types/?name=$PRODUCT_TYPE_NAME" | jq '.results[0].id')

if [ "$PRODUCT_TYPE_ID" = "null" ] || [ -z "$PRODUCT_TYPE_ID" ]; then
  echo "➕ Creating Product Type: $PRODUCT_TYPE_NAME"
  PRODUCT_TYPE_ID=$(curl -s -X POST "$DOJO_URL/api/v2/product_types/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{\"name\": \"$PRODUCT_TYPE_NAME\"}" | jq '.id')
fi

echo "✅ Product Type ID: $PRODUCT_TYPE_ID"

# Step 2: Get or create Product
echo "🔍 Checking for Product: $PRODUCT_NAME"
PRODUCT_ID=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/products/?name=$PRODUCT_NAME" | jq '.results[0].id')

if [ "$PRODUCT_ID" = "null" ] || [ -z "$PRODUCT_ID" ]; then
  echo "➕ Creating Product: $PRODUCT_NAME"
  PRODUCT_ID=$(curl -s -X POST "$DOJO_URL/api/v2/products/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{\"name\": \"$PRODUCT_NAME\", \"prod_type\": $PRODUCT_TYPE_ID}" | jq '.id')
fi

echo "✅ Product ID: $PRODUCT_ID"

# Step 3: Get or create Engagement
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

# Step 4: Upload scan
echo "📤 Uploading scan to DefectDojo..."
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
