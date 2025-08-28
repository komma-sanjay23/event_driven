import json
import os
import logging
import boto3
from botocore.exceptions import BotoCoreError, ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sfn_client = boto3.client('stepfunctions')
STATE_MACHINE_ARN = os.environ.get("STATE_MACHINE_ARN", "")

def _extract_records(event):
    out = []
    for rec in event.get("Records", []):
        if rec.get("eventSource") != "aws:s3":
            continue
        s3 = rec.get("s3", {})
        bucket = s3.get("bucket", {}).get("name")
        key = s3.get("object", {}).get("key")
        if bucket and key:
            out.append({"s3_bucket": bucket, "s3_key": key})
    return out

def handler(event, context):
    try:
        if isinstance(event, str):
            event = json.loads(event)

        logger.info("Collector received event: %s", json.dumps(event))

        if not STATE_MACHINE_ARN:
            raise RuntimeError("Missing env var STATE_MACHINE_ARN")

        s3_objects = _extract_records(event)
        if not s3_objects:
            logger.info("No S3 object records found")
            return {"statusCode": 200, "body": {"message": "no_records"}}

        for obj in s3_objects:
            try:
                response = sfn_client.start_execution(
                    stateMachineArn=STATE_MACHINE_ARN,
                    input=json.dumps(obj)
                )
                logger.info("Started Step Function for s3://%s/%s, executionArn=%s",
                            obj["s3_bucket"], obj["s3_key"], response.get("executionArn"))
            except (ClientError, BotoCoreError) as start_err:
                logger.exception("Failed to start Step Function for %s: %s", obj, start_err)
                # continue to attempt other records
        return {"statusCode": 200, "body": {"message": "started_step_function", "count": len(s3_objects)}}

    except (ClientError, BotoCoreError) as aws_err:
        logger.exception("AWS error in collector")
        return {"statusCode": 502, "body": {"error": "aws_error", "detail": str(aws_err)}}
    except Exception as e:
        logger.exception("Collector unexpected error")
        return {"statusCode": 500, "body": {"error": "internal_error", "detail": str(e)}}

