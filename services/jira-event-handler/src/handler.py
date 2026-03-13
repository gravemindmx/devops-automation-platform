"""
Jira Event Handler Lambda Function

Processes webhooks from Jira when issues are updated.
Sends notifications to Microsoft Teams with issue resolution details.

Triggers: Jira webhook on issue status change
"""

import json
import os
import urllib3
import boto3
import logging
from datetime import datetime, timezone
from typing import Any, Dict

# Initialize clients
http = urllib3.PoolManager()
lambda_client = boto3.client('lambda')

# Environment variables
TEAMS_WEBHOOK = os.environ.get('TEAMS_WEBHOOK')
JIRA_URL = os.environ.get('JIRA_URL', 'https://your-jira.atlassian.net')

# Logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')


def lambda_handler(event, context):
    """
    Main Lambda handler for Jira webhook events
    """
    
    try:
        logger.info(f"Received Jira webhook event: {json.dumps(event)}")
        
        # Parse the webhook payload
        payload = event if isinstance(event, dict) else json.loads(event)
        
        # Extract event type
        event_type = payload.get('webhookEvent', 'unknown')
        logger.info(f"Event type: {event_type}")
        
        # Process different event types
        if event_type == 'jira:issue_updated':
            return handle_issue_updated(payload)
        elif event_type == 'jira:issue_created':
            return handle_issue_created(payload)
        elif event_type == 'jira:issue_deleted':
            return handle_issue_deleted(payload)
        elif event_type == 'comment_created':
            return handle_comment_created(payload)
        else:
            logger.warning(f"Unknown event type: {event_type}")
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'Event type not handled'})
            }
            
    except Exception as e:
        logger.error(f"Error processing Jira webhook: {str(e)}", exc_info=True)
        return error_response(f"Internal error: {str(e)}")


def handle_issue_updated(payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle Jira issue update events
    Triggers when issue status, assignee, or other fields change
    """
    
    try:
        issue = payload.get('issue', {})
        changelog = payload.get('changelog', {})
        
        issue_key = issue.get('key', 'UNKNOWN')
        issue_fields = issue.get('fields', {})
        issue_summary = issue_fields.get('summary', 'No title')
        
        # Check if status changed (resolved)
        histories = changelog.get('histories', [])
        status_change = None
        
        for history in histories:
            items = history.get('items', [])
            for item in items:
                if item.get('field') == 'status':
                    old_status = item.get('fromString', '')
                    new_status = item.get('toString', '')
                    
                    if new_status.upper() in ['DONE', 'RESOLVED', 'CLOSED']:
                        status_change = {
                            'from': old_status,
                            'to': new_status,
                            'changed_at': history.get('created', '')
                        }
                        break
        
        if status_change:
            return handle_issue_resolved(payload, status_change)
        else:
            # Issue updated but not resolved - log it
            logger.info(f"Issue {issue_key} updated but not resolved")
            return success_response(f"Issue {issue_key} updated")
            
    except Exception as e:
        logger.error(f"Error handling issue update: {str(e)}")
        return error_response(f"Error: {str(e)}")


def handle_issue_resolved(payload: Dict[str, Any], status_change: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle issue resolution - send notification to Teams
    """
    
    try:
        issue = payload.get('issue', {})
        issue_key = issue.get('key', 'UNKNOWN')
        issue_fields = issue.get('fields', {})
        
        # Extract issue details
        issue_summary = issue_fields.get('summary', 'No title')
        assigned_user = issue_fields.get('assignee', {})
        assigned_name = assigned_user.get('displayName', 'Unassigned') if assigned_user else 'Unassigned'
        
        # Get changelog for resolution details
        changelog = payload.get('changelog', {})
        histories = changelog.get('histories', [])
        
        resolved_by = 'Unknown'
        resolved_at = utc_now_iso()
        
        for history in histories:
            resolved_by = history.get('author', {}).get('displayName', 'Unknown')
            resolved_at = history.get('created', resolved_at)
        
        # Calculate resolution time (if we have created date)
        time_to_resolve = 'N/A'
        created = issue_fields.get('created', '')
        if created and resolved_at:
            try:
                created_dt = datetime.fromisoformat(created.replace('Z', '+00:00'))
                resolved_dt = datetime.fromisoformat(resolved_at.replace('Z', '+00:00'))
                diff = resolved_dt - created_dt
                hours = diff.total_seconds() / 3600
                time_to_resolve = f"{int(hours)} hours {int(diff.total_seconds() % 3600 / 60)} minutes"
            except:
                pass
        
        # Build Teams message
        teams_message = build_resolution_message(
            issue_key=issue_key,
            summary=issue_summary,
            resolved_by=resolved_by,
            assigned_to=assigned_name,
            time_to_resolve=time_to_resolve,
            resolved_at=resolved_at
        )
        
        # Send to Teams
        send_teams_notification(teams_message)
        
        logger.info(f"Resolution notification sent for {issue_key}")
        
        return success_response(f"Notification sent for {issue_key}")
        
    except Exception as e:
        logger.error(f"Error handling issue resolution: {str(e)}")
        return error_response(f"Error: {str(e)}")


def handle_issue_created(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Handle issue creation events"""
    
    try:
        issue = payload.get('issue', {})
        issue_key = issue.get('key', 'UNKNOWN')
        
        logger.info(f"Issue created: {issue_key}")
        return success_response(f"Issue created: {issue_key}")
        
    except Exception as e:
        logger.error(f"Error handling issue creation: {str(e)}")
        return error_response(f"Error: {str(e)}")


def handle_issue_deleted(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Handle issue deletion events"""
    
    try:
        issue = payload.get('issue', {})
        issue_key = issue.get('key', 'UNKNOWN')
        
        logger.info(f"Issue deleted: {issue_key}")
        return success_response(f"Issue deleted: {issue_key}")
        
    except Exception as e:
        logger.error(f"Error handling issue deletion: {str(e)}")
        return error_response(f"Error: {str(e)}")


def handle_comment_created(payload: Dict[str, Any]) -> Dict[str, Any]:
    """Handle comment creation events"""
    
    try:
        issue = payload.get('issue', {})
        comment = payload.get('comment', {})
        
        issue_key = issue.get('key', 'UNKNOWN')
        comment_author = comment.get('author', {}).get('displayName', 'Unknown')
        
        logger.info(f"Comment added to {issue_key} by {comment_author}")
        return success_response(f"Comment on {issue_key}")
        
    except Exception as e:
        logger.error(f"Error handling comment: {str(e)}")
        return error_response(f"Error: {str(e)}")


def build_resolution_message(issue_key: str, summary: str, resolved_by: str,
                           assigned_to: str, time_to_resolve: str, resolved_at: str) -> Dict[str, Any]:
    """Build Teams message payload for issue resolution"""
    
    teams_payload = {
        "@type": "MessageCard",
        "@context": "https://schema.org/extensions",
        "summary": f"✅ Issue Resolved: {issue_key}",
        "themeColor": "28a745",  # Green
        "title": f"🎉 Jira Issue Resolved",
        "sections": [
            {
                "activityTitle": f"{issue_key}: {summary[:100]}",
                "activitySubtitle": "Status: RESOLVED ✅",
                "facts": [
                    {
                        "name": "Issue ID",
                        "value": issue_key
                    },
                    {
                        "name": "Resolved by",
                        "value": resolved_by
                    },
                    {
                        "name": "Assigned to",
                        "value": assigned_to
                    },
                    {
                        "name": "Time to resolve",
                        "value": time_to_resolve
                    },
                    {
                        "name": "Resolved at",
                        "value": resolved_at
                    }
                ],
                "markdown": True
            }
        ],
        "potentialAction": [
            {
                "@type": "OpenUri",
                "name": "View in Jira",
                "targets": [
                    {
                        "os": "default",
                        "uri": f"{JIRA_URL}/browse/{issue_key}"
                    }
                ]
            }
        ]
    }
    
    return teams_payload


def send_teams_notification(payload: dict) -> bool:
    """Send notification to Microsoft Teams"""
    
    try:
        if not TEAMS_WEBHOOK:
            logger.warning("TEAMS_WEBHOOK not configured")
            return False
        
        response = http.request(
            'POST',
            TEAMS_WEBHOOK,
            body=json.dumps(payload),
            headers={'Content-Type': 'application/json'},
            timeout=urllib3.Timeout(connect=5.0, read=10.0)
        )
        
        if response.status in [200, 201]:
            logger.info(f"Teams notification sent (status: {response.status})")
            return True
        else:
            logger.error(f"Teams notification failed (status: {response.status})")
            logger.error(f"Response: {response.data.decode('utf-8')}")
            return False
            
    except Exception as e:
        logger.error(f"Error sending Teams notification: {str(e)}")
        return False


def success_response(message: str = "Success") -> dict:
    """Return successful Lambda response"""
    return {
        'statusCode': 200,
        'body': json.dumps({'message': message})
    }


def error_response(message: str = "Error") -> dict:
    """Return error Lambda response"""
    return {
        'statusCode': 400,
        'body': json.dumps({'error': message})
    }
