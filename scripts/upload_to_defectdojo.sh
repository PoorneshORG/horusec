#!/bin/bash

set -e

# === Input arguments ===
DOJO_URL=$1
DOJO_API_KEY=$2
PRODUCT_NAME=$3
SCAN_FILE=$4
ENGAGEMENT_NAME=$5
TEST_TITLE=${6:-"Gitleaks Scan"}
PRODUCT_TYPE_NAME=${7:-"CI/CD"}

# === Validation ===
if [ -z "$DOJO_URL" ] || [ -z "$DOJO_API_KEY" ] || [ -z "$PRODUCT_NAME" ] || [ -z "$SCAN_FILE" ] || [ -z "$ENGAGEMENT_NAME" ]; then
  echo "Usage: $0 <DOJO_URL> <DOJO_API_KEY> <PRODUCT_NAME> <SCAN_FILE> <ENGAGEMENT_NAME> [TEST_TITLE] [PRODUCT_TYPE_NAME]"
  exit 1
fi

if [ ! -f "$SCAN_FILE" ]; then
  echo "❌ Scan file '$SCAN_FILE' not found!"
  exit 1
fi

DATE=$(date +%F)
AUTH_HEADER="Authorization: Token $DOJO_API_KEY"
JSON_HEADER="Content-Type: application/json"

echo "📤 Uploading $SCAN_FILE to DefectDojo product='$PRODUCT_NAME', engagement='$ENGAGEMENT_NAME'..."

# === Step 1: Get or create Product Type ===
echo "🔍 Fetching Product Type ID for '$PRODUCT_TYPE_NAME'"
PRODUCT_TYPE_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/product_types/?name=$PRODUCT_TYPE_NAME")
PRODUCT_TYPE_ID=$(echo "$PRODUCT_TYPE_RESPONSE" | jq '.results[0].id // empty')

if [ -z "$PRODUCT_TYPE_ID" ]; then
  echo "➕ Creating Product Type: $PRODUCT_TYPE_NAME"
  CREATE_RESPONSE=$(curl -s -X POST "$DOJO_URL/api/v2/product_types/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{\"name\": \"$PRODUCT_TYPE_NAME\"}")
  PRODUCT_TYPE_ID=$(echo "$CREATE_RESPONSE" | jq '.id // empty')

  if [ -z "$PRODUCT_TYPE_ID" ]; then
    echo "❌ Failed to create product type: $CREATE_RESPONSE"
    exit 1
  fi
fi
echo "✅ Product Type ID: $PRODUCT_TYPE_ID"

# === Step 2: Get or create Product ===
echo "🔍 Checking for Product: $PRODUCT_NAME"
PRODUCT_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/products/?name=$PRODUCT_NAME")
PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | jq '.results[0].id // empty')

if [ -z "$PRODUCT_ID" ]; then
  echo "➕ Creating Product: $PRODUCT_NAME"
  CREATE_RESPONSE=$(curl -s -X POST "$DOJO_URL/api/v2/products/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{\"name\": \"$PRODUCT_NAME\", \"prod_type\": $PRODUCT_TYPE_ID}")
  PRODUCT_ID=$(echo "$CREATE_RESPONSE" | jq '.id // empty')

  if [ -z "$PRODUCT_ID" ]; then
    echo "❌ Failed to create product: $CREATE_RESPONSE"
    exit 1
  fi
fi
echo "✅ Product ID: $PRODUCT_ID"

# === Step 3: Get or create Engagement ===
echo "🔍 Checking for Engagement: $ENGAGEMENT_NAME"
ENGAGEMENT_RESPONSE=$(curl -s -H "$AUTH_HEADER" "$DOJO_URL/api/v2/engagements/?product=$PRODUCT_ID&name=$ENGAGEMENT_NAME")
ENGAGEMENT_ID=$(echo "$ENGAGEMENT_RESPONSE" | jq '.results[0].id // empty')

if [ -z "$ENGAGEMENT_ID" ]; then
  echo "➕ Creating Engagement: $ENGAGEMENT_NAME"
  CREATE_RESPONSE=$(curl -s -X POST "$DOJO_URL/api/v2/engagements/" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "{
      \"product\": $PRODUCT_ID,
      \"name\": \"$ENGAGEMENT_NAME\",
      \"target_start\": \"$DATE\",
      \"target_end\": \"$DATE\",
      \"status\": \"In Progress\",
      \"engagement_type\": \"CI/CD\"
    }")
  ENGAGEMENT_ID=$(echo "$CREATE_RESPONSE" | jq '.id // empty')

  if [ -z "$ENGAGEMENT_ID" ]; then
    echo "❌ Failed to create engagement: $CREATE_RESPONSE"
    exit 1
  fi
fi
echo "✅ Engagement ID: $ENGAGEMENT_ID"

# === Step 4: Upload scan ===
echo "📤 Reimporting scan to DefectDojo..."

UPLOAD_RESPONSE=$(curl -s -w "%{http_code}" -o response.txt -X POST "$DOJO_URL/api/v2/reimport-scan/" \
  -H "$AUTH_HEADER" \
  -F "scan_date=$DATE" \
  -F "scan_type=Gitleaks Scan" \
  -F "active=true" \
  -F "verified=true" \
  -F "engagement=$ENGAGEMENT_ID" \
  -F "test_title=$TEST_TITLE - $DATE" \
  -F "close_old_findings=false" \
  -F "deduplication_on_engagement=true" \
  -F "file=@$SCAN_FILE")

HTTP_CODE=$(tail -n1 <<< "$UPLOAD_RESPONSE")

if [ "$HTTP_CODE" -ne 201 ] && [ "$HTTP_CODE" -ne 200 ]; then
  echo "❌ Failed to upload scan. Response:"
  cat response.txt
  exit 1
fi

echo "✅ Scan uploaded and consolidated!"
rm -f response.txt
