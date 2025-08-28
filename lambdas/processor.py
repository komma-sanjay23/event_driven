# processor.py (Lambda)
import json
import os
import logging
import boto3
from botocore.exceptions import BotoCoreError, ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
ddb = boto3.resource("dynamodb")
TABLE_NAME = os.environ.get("TABLE_NAME", "")

def _normalize(rec):
    user_id  = str(rec.get("user_id", "")).strip()
    event_ts = str(rec.get("event_ts", "")).strip()
    action   = str(rec.get("action", "")).strip().lower()
    metadata = rec.get("metadata") or {}
    if not user_id or not event_ts or not action:
        raise ValueError("missing required fields (user_id, event_ts, action)")
    return {
        "user_id": user_id,
        "event_ts": event_ts,
        "action": action,
        "metadata": metadata,
        "version": int(rec.get("version", 1)),
    }

def handler(event, context):
    try:
        if isinstance(event, str):
            event = json.loads(event)

        if not TABLE_NAME:
            raise RuntimeError("TABLE_NAME env var is missing")

        bucket = event.get("s3_bucket")
        key    = event.get("s3_key")
        if not bucket or not key:
            raise ValueError("Missing s3_bucket or s3_key")

        obj = s3.get_object(Bucket=bucket, Key=key)
        body = obj["Body"]

        table = ddb.Table(TABLE_NAME)
        ok, bad = 0, 0

        with table.batch_writer() as batch:   # removed overwrite_by_pkeys for compatibility
            for raw_line in body.iter_lines(chunk_size=64*1024):
                if not raw_line:
                    continue
                try:
                    # iter_lines yields bytes; decode to str first
                    if isinstance(raw_line, (bytes, bytearray)):
                        raw_line = raw_line.decode("utf-8")
                    rec = json.loads(raw_line)
                    norm = _normalize(rec)
                    batch.put_item(Item=norm)
                    ok += 1
                except (json.JSONDecodeError, ValueError) as parse_err:
                    bad += 1
                    logger.debug("Skipping bad line: %s", parse_err)


        logger.info("Processed s3://%s/%s -> ok=%d bad=%d", bucket, key, ok, bad)
        return {"statusCode": 200, "body": {"ok": ok, "bad": bad}}

    except (ClientError, BotoCoreError) as aws_err:
        logger.exception("AWS error in processor")
        return {"statusCode": 502, "body": {"error": "aws_error", "detail": str(aws_err)}}
    except Exception as e:
        logger.exception("Processor unexpected error")
        return {"statusCode": 500, "body": {"error": "internal_error", "detail": str(e)}}
