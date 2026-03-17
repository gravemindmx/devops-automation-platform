"""
Teams Notifier Lambda Function

Sends notifications to Microsoft Teams for various DevOps events:
- Build success/failure
- Deployment events
- Jira ticket updates
- Pipeline status changes

Triggered by: Jenkins, API Gateway, other services
"""

import json
import os
import urllib3
import logging
from datetime import datetime, timezone
from urllib.parse import urlparse
from typing import Dict, Any

# Initialize clients
http = urllib3.PoolManager()

# Environment variables
TEAMS_WEBHOOK = os.environ.get('TEAMS_WEBHOOK')

# Logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def lambda_handler(event, context):
    """
    Main Lambda handler for Teams notifications
    """
    
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Parse event
        if isinstance(event, str):
            payload = json.loads(event)
        else:
            payload = event

        # Health checks should validate handler logic without depending on external webhook availability.
        if payload.get('dry_run') is True:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Dry-run validation successful'})
            }
        
        # Determine event type and build appropriate message
        event_type = payload.get('event_type', 'unknown')
        
        if event_type == 'build_success':
            teams_message = format_build_success(payload)
        elif event_type == 'build_failure':
            teams_message = format_build_failure(payload)
        elif event_type == 'deployment_success':
            teams_message = format_deployment_success(payload)
        elif event_type == 'deployment_failure':
            teams_message = format_deployment_failure(payload)
        elif event_type == 'jira_resolved':
            teams_message = format_jira_resolved(payload)
        else:
            teams_message = format_generic_message(payload)
        
        # Send to Teams
        success = send_teams_notification(teams_message)
        
        if success:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Notification sent successfully'})
            }
        else:
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'Failed to send notification'})
            }
    
    except Exception as e:
        logger.error(f"Error processing event: {str(e)}", exc_info=True)
        return {
            'statusCode': 400,
            'body': json.dumps({'error': str(e)})
        }


def format_build_success(payload: Dict[str, Any]) -> Dict:
    """Format successful build notification"""
    
    build_number = payload.get('build_number', 'N/A')
    branch = payload.get('branch', 'unknown')
    commit = payload.get('commit', 'N/A')
    build_url = payload.get('build_url', '')
    environment = payload.get('environment', 'qa')
    
    message = {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": f"✅ Build #{build_number} - SUCCESS",
        "themeColor": "28a745",  # Green
        "title": "✅ Build Successful",
        "sections": [
            {
                "activityTitle": f"Build #{build_number} - {branch}",
                "activitySubtitle": f"Status: SUCCESS - Deployed to {environment.upper()}",
                "facts": [
                    {
                        "name": "Build Number",
                        "value": str(build_number)
                    },
                    {
                        "name": "Branch",
                        "value": branch
                    },
                    {
                        "name": "Commit",
                        "value": commit
                    },
                    {
                        "name": "Environment",
                        "value": environment.upper()
                    },
                    {
                        "name": "Time",
                        "value": utc_now_iso()
                    }
                ],
                "markdown": True
            }
        ],
        "potentialAction": [
            {
                "@type": "OpenUri",
                "name": "View Build in Jenkins",
                "targets": [
                    {
                        "os": "default",
                        "uri": build_url
                    }
                ]
            }
        ]
    }
    
    return message


def format_build_failure(payload: Dict[str, Any]) -> Dict:
    """Format failed build notification"""
    
    build_number = payload.get('build_number', 'N/A')
    branch = payload.get('branch', 'unknown')
    commit = payload.get('commit', 'N/A')
    error = payload.get('error', 'Unknown error')
    jira_ticket = payload.get('jira_ticket', '')
    build_url = payload.get('build_url', '')
    jira_url = payload.get('jira_url', '')
    
    facts = [
        {
            "name": "Build Number",
            "value": str(build_number)
        },
        {
            "name": "Branch",
            "value": branch
        },
        {
            "name": "Commit",
            "value": commit
        },
        {
            "name": "Error",
            "value": error[:200]  # Limit error message length
        },
        {
            "name": "Time",
            "value": utc_now_iso()
        }
    ]
    
    if jira_ticket:
        facts.append({
            "name": "Jira Ticket",
            "value": jira_ticket
        })
    
    message = {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": f"❌ Build #{build_number} - FAILED",
        "themeColor": "dc3545",  # Red
        "title": "❌ Build Failed",
        "sections": [
            {
                "activityTitle": f"Build #{build_number} - {branch}",
                "activitySubtitle": "Status: FAILED ❌",
                "facts": facts,
                "markdown": True
            }
        ],
        "potentialAction": []
    }
    
    if build_url:
        message["potentialAction"].append({
            "@type": "OpenUri",
            "name": "View Build in Jenkins",
            "targets": [
                {
                    "os": "default",
                    "uri": build_url
                }
            ]
        })
    
    if jira_ticket and jira_url:
        message["potentialAction"].append({
            "@type": "OpenUri",
            "name": "View Jira Ticket",
            "targets": [
                {
                    "os": "default",
                    "uri": f"{jira_url}/browse/{jira_ticket}"
                }
            ]
        })
    
    return message


def format_deployment_success(payload: Dict[str, Any]) -> Dict:
    """Format successful deployment notification"""
    
    environment = payload.get('environment', 'qa').upper()
    version = payload.get('version', 'N/A')
    deployed_by = payload.get('deployed_by', 'Automated')
    
    message = {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": f"✅ Deployment to {environment} - SUCCESS",
        "themeColor": "28a745",
        "title": "✅ Deployment Successful",
        "sections": [
            {
                "activityTitle": f"Deployed to {environment}",
                "activitySubtitle": f"Version: {version}",
                "facts": [
                    {
                        "name": "Environment",
                        "value": environment
                    },
                    {
                        "name": "Version",
                        "value": version
                    },
                    {
                        "name": "Deployed by",
                        "value": deployed_by
                    },
                    {
                        "name": "Time",
                        "value": utc_now_iso()
                    }
                ],
                "markdown": True
            }
        ]
    }
    
    return message


def format_deployment_failure(payload: Dict[str, Any]) -> Dict:
    """Format failed deployment notification"""
    
    environment = payload.get('environment', 'qa').upper()
    error = payload.get('error', 'Unknown error')
    
    message = {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": f"❌ Deployment to {environment} - FAILED",
        "themeColor": "dc3545",
        "title": "❌ Deployment Failed",
        "sections": [
            {
                "activityTitle": f"Failed to deploy to {environment}",
                "activitySubtitle": "Status: FAILED ❌",
                "facts": [
                    {
                        "name": "Environment",
                        "value": environment
                    },
                    {
                        "name": "Error",
                        "value": error[:200]
                    },
                    {
                        "name": "Time",
                        "value": utc_now_iso()
                    }
                ],
                "markdown": True
            }
        ]
    }
    
    return message


def format_jira_resolved(payload: Dict[str, Any]) -> Dict:
    """Format Jira issue resolved notification"""
    
    ticket_id = payload.get('ticket_id', 'UNKNOWN')
    summary = payload.get('summary', 'No title')
    resolved_by = payload.get('resolved_by', 'Unknown')
    time_to_resolve = payload.get('time_to_resolve', 'N/A')
    jira_url = payload.get('jira_url', '')
    
    message = {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": f"✅ {ticket_id} - Resolved",
        "themeColor": "28a745",
        "title": "✅ Jira Issue Resolved",
        "sections": [
            {
                "activityTitle": f"{ticket_id}: {summary}",
                "activitySubtitle": "Status: RESOLVED ✅",
                "facts": [
                    {
                        "name": "Ticket ID",
                        "value": ticket_id
                    },
                    {
                        "name": "Resolved by",
                        "value": resolved_by
                    },
                    {
                        "name": "Time to resolve",
                        "value": time_to_resolve
                    },
                    {
                        "name": "Resolved at",
                        "value": utc_now_iso()
                    }
                ],
                "markdown": True
            }
        ],
        "potentialAction": []
    }
    
    if jira_url:
        message["potentialAction"].append({
            "@type": "OpenUri",
            "name": "View in Jira",
            "targets": [
                {
                    "os": "default",
                    "uri": f"{jira_url}/browse/{ticket_id}"
                }
            ]
        })
    
    return message


def format_generic_message(payload: Dict[str, Any]) -> Dict:
    """Format generic notification"""
    
    message_text = payload.get('message', 'No message provided')
    status = payload.get('status', 'INFO')
    
    # Determine color based on status
    color_map = {
        'SUCCESS': '28a745',
        'FAILED': 'dc3545',
        'WARNING': 'ffc107',
        'INFO': '0275d8'
    }
    
    theme_color = color_map.get(status.upper(), '0275d8')
    
    message = {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": message_text,
        "themeColor": theme_color,
        "title": f"📢 {status}",
        "sections": [
            {
                "activityTitle": "DevOps Notification",
                "text": message_text,
                "facts": [
                    {
                        "name": "Status",
                        "value": status
                    },
                    {
                        "name": "Time",
                        "value": utc_now_iso()
                    }
                ],
                "markdown": True
            }
        ]
    }
    
    return message


def to_plain_text_message(payload: Dict[str, Any]) -> Dict[str, str]:
    """Build plain text payload for workflow-style Teams webhooks."""

    title = payload.get("title") or payload.get("summary") or "DevOps Notification"

    details = []
    sections = payload.get("sections") or []
    if sections and isinstance(sections[0], dict):
        first = sections[0]
        if first.get("activityTitle"):
            details.append(str(first.get("activityTitle")))
        if first.get("activitySubtitle"):
            details.append(str(first.get("activitySubtitle")))

        for fact in first.get("facts", []):
            if isinstance(fact, dict):
                name = fact.get("name")
                value = fact.get("value")
                if name and value is not None:
                    details.append(f"- {name}: {value}")

    body = "\n".join(details).strip()
    if body:
        text = f"{title}\n{body}"
    else:
        text = str(title)

    return {"text": text}


def send_teams_notification(payload: Dict) -> bool:
    """Send notification to Microsoft Teams"""
    
    try:
        if not TEAMS_WEBHOOK:
            logger.error("TEAMS_WEBHOOK not configured")
            return False

        parsed = urlparse(TEAMS_WEBHOOK)
        logger.info(
            "Sending Teams notification to host=%s path=%s",
            parsed.netloc,
            parsed.path[:48] + ("..." if len(parsed.path) > 48 else "")
        )
        logger.info(f"Sending Teams notification: {json.dumps(payload)}")
        
        response = http.request(
            'POST',
            TEAMS_WEBHOOK,
            body=json.dumps(payload),
            headers={'Content-Type': 'application/json'},
            timeout=urllib3.Timeout(connect=5.0, read=10.0)
        )
        
        if response.status in [200, 201, 202]:
            logger.info(f"Teams notification sent (status: {response.status})")
            return True
        else:
            logger.error(f"Teams notification failed (status: {response.status})")
            logger.error(f"Response: {response.data.decode('utf-8')}")

            # Workflow webhooks may reject MessageCard payloads. Retry with plain text payload.
            if response.status in [400, 405, 415, 422]:
                fallback_payload = to_plain_text_message(payload)
                logger.info("Retrying Teams notification using plain text payload format")
                fallback_response = http.request(
                    'POST',
                    TEAMS_WEBHOOK,
                    body=json.dumps(fallback_payload),
                    headers={'Content-Type': 'application/json'},
                    timeout=urllib3.Timeout(connect=5.0, read=10.0)
                )

                if fallback_response.status in [200, 201, 202]:
                    logger.info(
                        "Teams notification sent on fallback (status: %s)",
                        fallback_response.status
                    )
                    return True

                logger.error(
                    "Teams fallback failed (status: %s)",
                    fallback_response.status
                )
                logger.error(
                    "Fallback response: %s",
                    fallback_response.data.decode('utf-8')
                )

            return False
    
    except Exception as e:
        logger.error(f"Error sending Teams notification: {str(e)}")
        return False