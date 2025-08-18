import os, json, boto3, logging, uuid
from urllib.parse import unquote_plus

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REGION = os.getenv("AWS_REGION", "us-east-2")
SFN_ARN_PARAM = os.getenv("SFN_ARN_PARAM", "/pipelines/user-activity/stateMachineArn")

ssm = boto3.client("ssm", region_name=REGION)
sfn = boto3.client("stepfunctions", region_name=REGION)

_cached_sfn_arn = None

def _get_state_machine_arn():
    global _cached_sfn_arn
    if _cached_sfn_arn:
        return _cached_sfn_arn
    resp = ssm.get_parameter(Name=SFN_ARN_PARAM)
    _cached_sfn_arn = resp["Parameter"]["Value"]
    return _cached_sfn_arn

def lambda_handler(event, context):
    sm_arn = _get_state_machine_arn()
    started = 0

    # Expect S3 Put events
    for r in event.get("Records", []):
        bucket = r["s3"]["bucket"]["name"]
        key    = unquote_plus(r["s3"]["object"]["key"])

        exec_name = f"ingest-{uuid.uuid4().hex[:16]}"
        payload = {"bucket": bucket, "key": key}
        logger.info("Starting SFN execution: %s | input=%s", exec_name, payload)

        sfn.start_execution(
            stateMachineArn=sm_arn,
            name=exec_name,
            input=json.dumps(payload)
        )
        started += 1

    return {"ok": True, "started": started}







