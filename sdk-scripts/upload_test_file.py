import os, json, gzip, uuid, boto3
from io import BytesIO
from datetime import datetime

REGION = os.getenv("AWS_REGION", "us-east-2")
BUCKET = os.getenv("BUCKET", os.environ.get("S3_BUCKET", "user-activity-bucket-demo-1234"))

s3 = boto3.client("s3", region_name=REGION)

def make_records(n=1000):
    now = datetime.utcnow().isoformat()
    for i in range(n):
        yield {
            "user_id": f"user-{i%100}",
            "timestamp": now,
            "event": "view",
            "product_id": f"sku-{i%250}",
            "price": float((i % 20) + 0.99)
        }

def main():
    key = f"ingest/{datetime.utcnow().strftime('%Y/%m/%d')}/sample-{uuid.uuid4().hex[:8]}.jsonl.gz"
    buf = BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
        for rec in make_records(5000):
            gz.write((json.dumps(rec) + "\n").encode("utf-8"))
    buf.seek(0)
    s3.put_object(Bucket=BUCKET, Key=key, Body=buf.getvalue(), ContentType="application/gzip")
    print("Uploaded:", f"s3://{BUCKET}/{key}")

if __name__ == "__main__":
    main()



