"""
Teams Notifier Lambda Function.

Sends notifications to Microsoft Teams for DevOps pipeline events.
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
TEAMS_FAILURE_WEBHOOK = os.environ.get('TEAMS_FAILURE_WEBHOOK') or TEAMS_WEBHOOK

# Logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


STATUS_BY_EVENT = {
    "build_in_progress": "EN_PROCESO",
    "build_failure": "FALLIDO",
    "deployment_failure": "FALLIDO",
    "build_success": "EFECTIVO",
    "deployment_success": "EFECTIVO",
    "blue_green_completed": "COMPLETADO",
    "completado_blue_green": "COMPLETADO",
}


def _repo_name(repository: str) -> str:
    if not repository:
        return "Aplicacion"
    repo = repository.rsplit("/", 1)[-1]
    if repo.endswith(".git"):
        repo = repo[:-4]
    return repo or "Aplicacion"


def build_notification_title(payload: Dict[str, Any]) -> str:
    app_name = str(payload.get("app_name") or _repo_name(str(payload.get("repository", ""))))
    environment = str(payload.get("environment") or "qa").upper()
    status = str(payload.get("status") or "").strip().upper()

    if not status:
        status = STATUS_BY_EVENT.get(str(payload.get("event_type", "")).lower(), "INFO")

    status_text = {
        "EN_PROCESO": "EN PROCESO",
        "FALLIDO": "FALLIDO",
        "EFECTIVO": "EFECTIVO",
        "COMPLETADO": "COMPLETADO (BLUE/GREEN)",
    }.get(status, status)

    return f"{app_name} | {environment} | {status_text}"


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def parse_event_payload(event: Any) -> Dict[str, Any]:
    """Parse Lambda event payload for direct invoke and API Gateway HTTP API v2."""
    if event is None:
        return {}

    if isinstance(event, str):
        return json.loads(event)

    if not isinstance(event, dict):
        return {}

    # API Gateway HTTP API v2 payload: business payload comes in body.
    if "version" in event and "requestContext" in event and "body" in event:
        body = event.get("body")
        if body is None:
            return {}

        if isinstance(body, dict):
            payload = body
        else:
            payload = json.loads(body)

        if event.get("isBase64Encoded"):
            # Current integration sends JSON, so keep explicit failure for malformed data.
            raise ValueError("Base64-encoded payload is not supported for notify endpoint")

        return payload if isinstance(payload, dict) else {}

    return event


def lambda_handler(event, context):
    """
    Main Lambda handler for Teams notifications
    """
    
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        payload = parse_event_payload(event)

        payload.setdefault("status", STATUS_BY_EVENT.get(str(payload.get("event_type", "")).lower(), payload.get("status", "INFO")))
        payload.setdefault("title", build_notification_title(payload))

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
        elif event_type == 'build_in_progress':
            teams_message = format_generic_message(payload)
        elif event_type in ('blue_green_completed', 'completado_blue_green'):
            teams_message = format_generic_message(payload)
        else:
            teams_message = format_generic_message(payload)
        
        # Send the raw event payload to Power Automate so that
        # triggerBody() fields (build_number, status, etc.) are accessible
        # in the AdaptiveCard expressions on the Power Automate side.
        success = send_teams_notification(payload)
        
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
    resolved_by = payload.get('resolved_by', '')
    
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
            "name": "Environment",
            "value": environment.upper()
        },
    ]

    if resolved_by:
        facts.append({
            "name": "Resuelto por",
            "value": resolved_by
        })

    facts.append({
        "name": "Time",
        "value": utc_now_iso()
    })

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
                "facts": facts,
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
    build_url = payload.get('build_url', '')
    
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

    # Handle flat event payload (sent from Jenkins via Lambda)
    if "event_type" in payload or "build_number" in payload:
        build_number = payload.get("build_number", "N/A")
        status = payload.get("status", payload.get("event_type", "Notification"))
        branch = payload.get("branch", "")
        commit = payload.get("commit", "")
        environment = payload.get("environment", "")
        message = payload.get("message", "")
        title = payload.get("title") or build_notification_title(payload)
        lines = [title, f"Build #{build_number} - {status}"]
        if branch:
            lines.append(f"- Branch: {branch}")
        if commit:
            lines.append(f"- Commit: {commit}")
        if environment:
            lines.append(f"- Environment: {environment}")
        if message:
            lines.append(f"- Message: {message}")
        return {"text": "\n".join(lines)}

    # Legacy: Handle MessageCard format
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


def _target_webhook(payload: Dict[str, Any]) -> str:
    status = str(payload.get("status", "")).upper().strip()
    event_type = str(payload.get("event_type", "")).lower().strip()

    if status == "FALLIDO" or event_type in {"build_failure", "deployment_failure"}:
        return TEAMS_FAILURE_WEBHOOK

    return TEAMS_WEBHOOK


def _build_outbound_payload(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Build webhook payload compatible with both direct and wrapped-flow triggers."""

    outbound = dict(payload)
    text_value = outbound.get("text") or to_plain_text_message(payload).get("text", "")

    if text_value:
        outbound.setdefault("text", text_value)

    if "summary" not in outbound:
        outbound["summary"] = str(outbound.get("title") or text_value or "DevOps Notification")

    # Some Power Automate templates resolve values via triggerBody()['body'][...].
    if not isinstance(outbound.get("body"), dict):
        outbound["body"] = dict(payload)

    return outbound


def send_teams_notification(payload: Dict) -> bool:
    """Send notification to Microsoft Teams"""
    
    try:
        webhook_url = _target_webhook(payload)

        if not webhook_url:
            logger.error("No Teams webhook configured for payload status/event")
            return False

        parsed = urlparse(webhook_url)
        logger.info(
            "Sending Teams notification to host=%s path=%s",
            parsed.netloc,
            parsed.path[:48] + ("..." if len(parsed.path) > 48 else "")
        )
        outbound_payload = _build_outbound_payload(payload)
        logger.info(f"Sending Teams notification: {json.dumps(outbound_payload)}")
        
        response = http.request(
            'POST',
            webhook_url,
            body=json.dumps(outbound_payload),
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
                    webhook_url,
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