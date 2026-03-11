import importlib.util
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "src" / "handler.py"
SPEC = importlib.util.spec_from_file_location("jira_event_handler", MODULE_PATH)
jira_handler = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(jira_handler)


def test_issue_created_event_returns_200():
    event = {
        "webhookEvent": "jira:issue_created",
        "issue": {"key": "DEVOPS-123"},
    }

    response = jira_handler.lambda_handler(event, None)

    assert response["statusCode"] == 200


def test_issue_updated_resolution_sends_notification():
    event = {
        "webhookEvent": "jira:issue_updated",
        "issue": {
            "key": "DEVOPS-124",
            "fields": {
                "summary": "Deploy failure",
                "created": "2026-03-10T10:00:00.000+0000",
                "assignee": {"displayName": "QA Team"},
            },
        },
        "changelog": {
            "histories": [
                {
                    "created": "2026-03-10T12:00:00.000+0000",
                    "author": {"displayName": "Dev User"},
                    "items": [
                        {
                            "field": "status",
                            "fromString": "To Do",
                            "toString": "Resolved",
                        }
                    ],
                }
            ]
        },
    }

    with patch.object(jira_handler, "send_teams_notification", return_value=True) as mocked_send:
        response = jira_handler.lambda_handler(event, None)

    assert response["statusCode"] == 200
    mocked_send.assert_called_once()


def test_unknown_webhook_event_is_ignored_cleanly():
    response = jira_handler.lambda_handler({"webhookEvent": "jira:unknown"}, None)

    assert response["statusCode"] == 200