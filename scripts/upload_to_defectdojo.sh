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

function api_post() {
  # $1 = URL, $2 = JSON payload
  response=$(curl -s -w "\n%{http_code}" -X POST "$1" \
    -H "$AUTH_HEADER" -H "$JSON_HEADER" \
    -d "$2")
  http_body=$(echo "$response" | head -n -1)
  http_code=$(echo "$response" | tail -n1)

  echo "$http_body"
  echo "$http_code"
}

function api_get() {
  # $1 = URL
  response=$(curl -s -w "\n%{http_code}" -H "$AUTH_HEADER" "$1")
  http_body=$(echo "$response" | head -n -1)
  http_code=$(echo "$response" | tail -n1)

  echo "$http_body"
  echo "$http_code"
}

echo "🔍 Checking for Product: $REPO_NAME"
read -r body code < <(api_get "$DOJO_URL/api/v2/products/?name=$REPO_NAME")

if [ "$code" -ne 200 ]; then
  echo "❌ Failed to get product: HTTP $code"
  echo "Response: $body"
  exit 1
fi

PRODUCT_ID=$(echo "$body" | jq -r '.results[0].id')

if [ "$PRODUCT_ID" == "null" ] || [ -z "$PRODUCT_ID" ]; then
  echo "➕ Creating Product: $REPO_NAME"
  payload="{\"name\": \"$REPO_NAME\", \"prod_type\": $PRODUCT_TYPE_ID}"
  read -r body code < <(api_post "$DOJO_URL/api/v2/products/" "$payload")
  if [ "$code" -ne 201 ]; then
    echo "❌ Failed to create product: HTTP $code"
    echo "Response: $body"
    exit 1
  fi
  PRODUCT_ID=$(echo "$body" | jq -r '.id')
fi

echo "✅ Product ID: $PRODUCT_ID"

echo "🔍 Checking for Engagement: $ENGAGEMENT_NAME"
read -r body code < <(api_get "$DOJO_URL/api/v2/engagements/?product=$PRODUCT_ID&name=$ENGAGEMENT_NAME")

if [ "$code" -ne 200 ]; then
  echo "❌ Failed to get engagement: HTTP $code"
  echo "Response: $body"
  exit 1
fi

ENGAGEMENT_ID=$(echo "$body" | jq -r '.results[0].id')

if [ "$ENGAGEMENT_ID" == "null" ] || [ -z "$ENGAGEMENT_ID" ]; then
  echo "➕ Creating Engagement: $ENGAGEMENT_NAME"
  payload="{
    \"product\": $PRODUCT_ID,
    \"name\": \"$ENGAGEMENT_NAME\",
    \"target_start\": \"$DATE\",
    \"target_end\": \"$DATE\",
    \"status\": \"In Progress\",
    \"engagement_type\": \"CI/CD\"
  }"
  read -r body code < <(api_post "$DOJO_URL/api/v2/engagements/" "$payload")
  if [ "$code" -ne 201 ]; then
    echo "❌ Failed to create engagement: HTTP $code"
    echo "Response: $body"
    exit 1
  fi
  ENGAGEMENT_ID=$(echo "$body" | jq -r '.id')
fi

echo "✅ Engagement ID: $ENGAGEMENT_ID"

echo "🔍 Checking for Test: $TEST_TITLE"
read -r body code < <(api_get "$DOJO_URL/api/v2/tests/?engagement=$ENGAGEMENT_ID")

if [ "$code" -ne 200 ]; then
  echo "❌ Failed to get tests: HTTP $code"
  echo "Response: $body"
  exit 1
fi

TEST_ID=$(echo "$body" | jq -r ".results[] | select(.title==\"$TEST_TITLE\") | .id")

if [ -z "$TEST_ID" ] || [ "$TEST_ID" == "null" ]; then
  echo "➕ Creating Test: $TEST_TITLE"
  payload="{
    \"engagement\": $ENGAGEMENT_ID,
    \"title\": \"$TEST_TITLE\",
    \"scan_type\": \"Gitleaks Scan\",
    \"target_start\": \"$DATE\",
    \"target_end\": \"$DATE\"
  }"
  read -r body code < <(api_post "$DOJO_URL/api/v2/tests/" "$payload")
  if [ "$code" -ne 201 ]; then
    echo "❌ Failed to create test: HTTP $code"
    echo "Response: $body"
    exit 1
  fi
  TEST_ID=$(echo "$body" | jq -r '.id')
fi

echo "✅ Test ID: $TEST_ID"

echo "📤 Reimporting scan to DefectDojo..."
response=$(curl -s -w "\n%{http_code}" -X POST "$DOJO_URL/api/v2/reimport-scan/" \
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

http_body=$(echo "$response" | head -n -1)
http_code=$(echo "$response" | tail -n1)

if [ "$http_code" -ne 201 ]; then
  echo "❌ Failed to upload scan: HTTP $http_code"
  echo "Response: $http_body"
  exit 1
fi

echo "✅ Scan uploaded and consolidated!"
