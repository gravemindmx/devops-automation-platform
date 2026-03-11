import json
import urllib3
import os

http = urllib3.PoolManager()

TEAMS_WEBHOOK = os.environ['TEAMS_WEBHOOK']

def lambda_handler(event, context):

    status = event.get("status")
    message = event.get("message")
    build = event.get("build")

    text = f"""
Pipeline Status: {status}
Build: {build}
Message: {message}
"""

    payload = {
        "text": text
    }

    response = http.request(
        "POST",
        TEAMS_WEBHOOK,
        body=json.dumps(payload),
        headers={"Content-Type": "application/json"}
    )

    return {
        "statusCode": 200,
        "body": json.dumps("Notification sent")
    }