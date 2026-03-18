#!/bin/bash
# Create Jira Issue for Build Failures
# Automatically creates a Jira ticket when a Jenkins build fails

set -e

# Parameters
JIRA_URL="${1:-}"
JIRA_API_TOKEN="${2:-}"
JIRA_PROJECT_KEY="${3:-NFRTST}"
BUILD_NUMBER="${4:-}"
BUILD_URL="${5:-}"
BRANCH_NAME="${6:-develop}"
COMMIT_HASH="${7:-}"
ERROR_MESSAGE="${8:-Build failed - see logs}"
ASSIGNEE_USER="${9:-qa-team}"

# Validation
if [ -z "$JIRA_URL" ] || [ -z "$JIRA_API_TOKEN" ]; then
    echo "❌ Error: Jira URL and API token are required"
    echo "Usage: $0 <jira_url> <jira_api_token> <project_key> <build_number> <build_url> <branch> <commit> <error_message> [assignee]"
    exit 1
fi

echo "════════════════════════════════════════════════════════════"
echo "Creating Jira Issue for Build Failure"
echo "════════════════════════════════════════════════════════════"
echo "Project: $JIRA_PROJECT_KEY"
echo "Build: #$BUILD_NUMBER"
echo "Branch: $BRANCH_NAME"
echo "Commit: $COMMIT_HASH"
echo "════════════════════════════════════════════════════════════"

# Sanitize error message
ERROR_SANITIZED=$(echo "$ERROR_MESSAGE" | sed 's/"//g' | cut -c1-500)

# Create Jira issue via API
echo "📋 Creating Jira issue..."

ISSUE_RESPONSE=$(curl -s -X POST \
    "${JIRA_URL}/rest/api/3/issue" \
    -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @- <<EOF
{
  "fields": {
    "project": {
      "key": "${JIRA_PROJECT_KEY}"
    },
    "summary": "[BUILD #${BUILD_NUMBER} FAILED] - ${BRANCH_NAME} branch deployment",
    "description": {
      "version": 3,
      "type": "doc",
      "content": [
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "Automated build failure notification",
              "marks": [{"type": "strong"}]
            }
          ]
        },
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "\nBuild Details:"
            }
          ]
        },
        {
          "type": "bulletList",
          "content": [
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [{"type": "text", "text": "Build Number: ${BUILD_NUMBER}"}]
                }
              ]
            },
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [{"type": "text", "text": "Branch: ${BRANCH_NAME}"}]
                }
              ]
            },
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [{"type": "text", "text": "Commit: ${COMMIT_HASH}"}]
                }
              ]
            },
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [{"type": "text", "text": "Error: ${ERROR_SANITIZED}"}]
                }
              ]
            },
            {
              "type": "listItem",
              "content": [
                {
                  "type": "paragraph",
                  "content": [
                    {
                      "type": "text",
                      "text": "Jenkins Build: ",
                      "marks": [{"type": "link", "attrs": {"href": "${BUILD_URL}"}}]
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    },
    "issuetype": {
      "name": "Bug"
    },
    "priority": {
      "name": "High"
    },
    "labels": [
      "jenkins",
      "failed-build",
      "automated",
      "${BRANCH_NAME}"
    ]
  }
}
EOF
)

# Extract issue key from response
ISSUE_KEY=$(echo "$ISSUE_RESPONSE" | grep -o '"key":"[^"]*' | head -1 | cut -d'"' -f4)

if [ -n "$ISSUE_KEY" ] && [ "$ISSUE_KEY" != "null" ]; then
    echo "✅ Jira issue created successfully"
    echo "   Issue Key: $ISSUE_KEY"
    echo "   URL: ${JIRA_URL}/browse/${ISSUE_KEY}"
    
    # Try to assign the issue (optional)
    if [ -n "$ASSIGNEE_USER" ]; then
        echo "👤 Attempting to assign issue..."
        
        ASSIGN_RESPONSE=$(curl -s -X PUT \
            "${JIRA_URL}/rest/api/3/issue/${ISSUE_KEY}/assignee" \
            -H "Authorization: Bearer ${JIRA_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d @- <<EOF
{
  "accountId": "${ASSIGNEE_USER}"
}
EOF
) 2>/dev/null || true
        
        if echo "$ASSIGN_RESPONSE" | grep -q "error"; then
            echo "⚠️  Assignment may have failed (will be assigned manually)"
        else
            echo "✓ Issue assigned"
        fi
    fi
    
    # Output the issue key for use in other scripts
    echo "$ISSUE_KEY"
    exit 0
else
    echo "❌ Failed to create Jira issue"
    echo "Response: $ISSUE_RESPONSE"
    exit 1
fi
