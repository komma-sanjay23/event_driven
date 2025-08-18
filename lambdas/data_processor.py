import os, json, gzip, boto3, logging
from decimal import Decimal
from typing import Iterable
from urllib.parse import unquote_plus

REGION = os.getenv("AWS_REGION", "us-east-2")
TABLE_NAME = os.environ["DDB_TABLE"]

dynamodb = boto3.resource("dynamodb", region_name=REGION)
table = dynamodb.Table(TABLE_NAME)
s3 = boto3.client("s3", region_name=REGION)

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def _iter_lines_from_s3(bucket: str, key: str) -> Iterable[str]:
    obj = s3.get_object(Bucket=bucket, Key=key)
    body = obj["Body"]                               # StreamingBody is fine for GzipFile
    with gzip.GzipFile(fileobj=body) as gz:
        for raw in gz:
            yield raw.decode("utf-8").rstrip("\n")

def _process(bucket: str, key: str):
    total = 0
    written = 0
    errors = 0
    with table.batch_writer(overwrite_by_pkeys=("user_id", "timestamp")) as bw:
        for raw in _iter_lines_from_s3(bucket, key):
            total += 1
            try:
                item = json.loads(raw, parse_float=Decimal, parse_int=Decimal)

                # ensure keys (table is HASH user_id (S), RANGE timestamp (S))
                if not item.get("user_id"):
                    raise ValueError("Missing user_id")
                ts = item.get("timestamp")
                if isinstance(ts, (int, float, Decimal)):
                    item["timestamp"] = str(ts)

                bw.put_item(Item=item)
                written += 1
            except Exception as e:
                errors += 1
                if errors <= 10:
                    logger.exception("Bad row #%s from %s/%s: %s", total, bucket, key, e)
    return {"ok": True, "lines": total, "written": written, "errors": errors}

def lambda_handler(event, context):
    if "bucket" in event and "key" in event:
        return _process(event["bucket"], event["key"])

    if "Records" in event:
        agg = {"ok": True, "lines": 0, "written": 0, "errors": 0}
        for r in event["Records"]:
            bucket = r["s3"]["bucket"]["name"]
            key    = unquote_plus(r["s3"]["object"]["key"])
            res = _process(bucket, key)
            for k in agg: 
                if k in res: agg[k] += res[k]
        return agg

    return {"ok": False, "error": "unsupported_event_shape"}



