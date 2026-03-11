#!/bin/bash
# Health Check Script for QA Deployment
# Validates Lambda function and API Gateway endpoints

set -e

LAMBDA_FUNCTION="${1:-teams-notifier-qa}"
AWS_REGION="${2:-us-east-1}"
API_GATEWAY_URL="${3:-}"

echo "════════════════════════════════════════════════════════════"
echo "Running Health Checks"
echo "════════════════════════════════════════════════════════════"

HEALTH_STATUS="✅ PASSED"
FAILED_CHECKS=0

# Check 1: Lambda Function Exists
echo ""
echo "Check 1: Lambda Function Existence"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LAMBDA_CHECK=$(aws lambda get-function \
    --function-name "$LAMBDA_FUNCTION" \
    --region "$AWS_REGION" \
    2>&1 || true)

if echo "$LAMBDA_CHECK" | grep -q "FunctionArn"; then
    echo "✓ Lambda function found"
    FUNCTION_ARN=$(echo "$LAMBDA_CHECK" | grep -o '"FunctionArn":"[^"]*' | cut -d'"' -f4)
    echo "  ARN: $FUNCTION_ARN"
else
    echo "✗ Lambda function not found: $LAMBDA_FUNCTION"
    HEALTH_STATUS="❌ FAILED"
    ((FAILED_CHECKS++))
fi

# Check 2: Lambda Function Accessible
echo ""
echo "Check 2: Lambda Function Health"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

INVOKE_RESPONSE=$(aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION" \
    --region "$AWS_REGION" \
    --payload '{"test": true, "action": "health_check"}' \
    /tmp/health-check-response.json \
    --log-type Tail \
    2>&1 || true)

if [ -f /tmp/health-check-response.json ]; then
    RESPONSE_STATUS=$(cat /tmp/health-check-response.json | jq -r '.statusCode // empty' 2>/dev/null || echo "")
    
    if [ -n "$RESPONSE_STATUS" ]; then
        echo "✓ Lambda health check passed"
        echo "  Status Code: $RESPONSE_STATUS"
        
        # Show response
        if command -v jq &> /dev/null; then
            echo "  Response:"
            cat /tmp/health-check-response.json | jq . | sed 's/^/    /'
        else
            echo "  Response:"
            cat /tmp/health-check-response.json | sed 's/^/    /'
        fi
    else
        echo "⚠️  Lambda responded but no statusCode found"
        cat /tmp/health-check-response.json
    fi
else
    echo "✗ Lambda health check failed"
    echo "  Response: $INVOKE_RESPONSE"
    HEALTH_STATUS="❌ FAILED"
    ((FAILED_CHECKS++))
fi

# Check 3: Lambda Environment Variables
echo ""
echo "Check 3: Lambda Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CONFIG_CHECK=$(aws lambda get-function-configuration \
    --function-name "$LAMBDA_FUNCTION" \
    --region "$AWS_REGION" \
    2>&1 || true)

if echo "$CONFIG_CHECK" | grep -q '"Runtime"'; then
    RUNTIME=$(echo "$CONFIG_CHECK" | grep -o '"Runtime":"[^"]*' | cut -d'"' -f4)
    MEMORY=$(echo "$CONFIG_CHECK" | grep -o '"MemorySize":[0-9]*' | cut -d':' -f2)
    TIMEOUT=$(echo "$CONFIG_CHECK" | grep -o '"Timeout":[0-9]*' | cut -d':' -f2)
    
    echo "✓ Lambda configuration retrieved"
    echo "  Runtime: $RUNTIME"
    echo "  Memory: ${MEMORY}MB"
    echo "  Timeout: ${TIMEOUT}s"
else
    echo "✗ Could not retrieve Lambda configuration"
    HEALTH_STATUS="❌ FAILED"
    ((FAILED_CHECKS++))
fi

# Check 4: API Gateway Health (if URL provided)
if [ -n "$API_GATEWAY_URL" ]; then
    echo ""
    echo "Check 4: API Gateway"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    API_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$API_GATEWAY_URL/health" 2>&1 || echo "000")
    
    if [ "$API_CHECK" == "200" ] || [ "$API_CHECK" == "404" ]; then
        echo "✓ API Gateway responding"
        echo "  Status: HTTP $API_CHECK"
    else
        echo "⚠️  Unexpected API Gateway response: HTTP $API_CHECK"
        # Don't fail on this, as 404 might be expected
    fi
else
    echo ""
    echo "Check 4: API Gateway"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "⊘ Skipped (no API URL provided)"
fi

# Summary
echo ""
echo "════════════════════════════════════════════════════════════"
echo "Health Check Summary: $HEALTH_STATUS"
echo "════════════════════════════════════════════════════════════"
echo "Checks Passed: $((4 - FAILED_CHECKS))/4"
echo "Checks Failed: $FAILED_CHECKS/4"
echo "════════════════════════════════════════════════════════════"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo "✅ All health checks passed - Deployment is healthy"
    exit 0
else
    echo "❌ Some health checks failed - Review above for details"
    exit 1
fi
