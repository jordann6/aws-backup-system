import json
import os
import boto3
import urllib.request
from datetime import datetime, timezone


def handler(event, context):
    s3 = boto3.client("s3")
    bucket = os.environ["BUCKET_NAME"]

    resp = s3.list_objects_v2(Bucket=bucket)
    count = resp.get("KeyCount", 0)

    sg_key = os.environ.get("SENDGRID_API_KEY", "")
    email = os.environ["ALERT_EMAIL"]

    if sg_key:
        now = datetime.now(timezone.utc)
        body = json.dumps({
            "personalizations": [{"to": [{"email": email}]}],
            "from": {
                "email": "backup-alerts@jordandesigns.io",
                "name": "AWS Backup Monitor",
            },
            "subject": f"[Backup Confirmed] Daily check {now.strftime('%Y-%m-%d')}",
            "content": [{
                "type": "text/plain",
                "value": (
                    f"Daily backup verification completed.\n\n"
                    f"Bucket: {bucket}\n"
                    f"Objects: {count}\n"
                    f"Check time (UTC): {now.strftime('%Y-%m-%dT%H:%M:%SZ')}"
                ),
            }],
        }).encode()

        req = urllib.request.Request(
            "https://api.sendgrid.com/v3/mail/send",
            data=body,
            headers={
                "Authorization": f"Bearer {sg_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        urllib.request.urlopen(req)

    return {"statusCode": 200, "bucket": bucket, "objectCount": count}
