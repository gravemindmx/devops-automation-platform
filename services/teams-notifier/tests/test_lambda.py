import importlib.util
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace


MODULE_PATH = Path(__file__).resolve().parents[1] / "src" / "lambda.py"
SPEC = importlib.util.spec_from_file_location("teams_notifier_lambda", MODULE_PATH)
teams_lambda = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(teams_lambda)


def test_build_success_event_returns_200():
    event = {
        "event_type": "build_success",
        "build_number": "123",
        "branch": "main",
        "commit": "abc123",
        "build_url": "http://jenkins.example.com/job/123",
    }

    with patch.object(teams_lambda, "send_teams_notification", return_value=True) as mocked_send:
        response = teams_lambda.lambda_handler(event, None)

    assert response["statusCode"] == 200
    mocked_send.assert_called_once()


def test_build_failure_event_returns_200():
    event = {
        "event_type": "build_failure",
        "build_number": "124",
        "branch": "develop",
        "error": "Test failed",
    }

    with patch.object(teams_lambda, "send_teams_notification", return_value=True) as mocked_send:
        response = teams_lambda.lambda_handler(event, None)

    assert response["statusCode"] == 200
    mocked_send.assert_called_once()


def test_unknown_event_uses_generic_formatter():
    event = {"message": "Generic notification", "status": "INFO"}

    with patch.object(teams_lambda, "send_teams_notification", return_value=True) as mocked_send:
        response = teams_lambda.lambda_handler(event, None)

    assert response["statusCode"] == 200
    mocked_send.assert_called_once()


def test_dry_run_skips_notification_and_returns_200():
    event = {
        "event_type": "build_success",
        "dry_run": True,
    }

    with patch.object(teams_lambda, "send_teams_notification") as mocked_send:
        response = teams_lambda.lambda_handler(event, None)

    assert response["statusCode"] == 200
    mocked_send.assert_not_called()


def test_send_teams_notification_accepts_202_status():
    with patch.object(
        teams_lambda.http,
        "request",
        return_value=SimpleNamespace(status=202, data=b""),
    ):
        with patch.object(
            teams_lambda,
            "TEAMS_WEBHOOK",
            "https://example.powerplatform.com/flow",
        ):
            result = teams_lambda.send_teams_notification({"text": "ok"})

    assert result is True


def test_build_notification_title_uses_app_and_environment():
    payload = {
        "event_type": "build_in_progress",
        "app_name": "mi-api",
        "environment": "prod",
    }

    title = teams_lambda.build_notification_title(payload)

    assert title == "mi-api | PROD | EN PROCESO"


def test_lambda_handler_sets_default_title_and_status_for_completed_blue_green():
    event = {
        "event_type": "completado_blue_green",
        "repository": "https://github.com/iMony-Tech/mi-app.git",
        "environment": "qa",
        "build_number": "321",
    }

    with patch.object(teams_lambda, "send_teams_notification", return_value=True) as mocked_send:
        response = teams_lambda.lambda_handler(event, None)

    assert response["statusCode"] == 200
    sent_payload = mocked_send.call_args[0][0]
    assert sent_payload["status"] == "COMPLETADO"
    assert sent_payload["title"] == "mi-app | QA | COMPLETADO (BLUE/GREEN)"