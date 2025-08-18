import os, json, gzip, uuid, boto3, concurrent.futures, argparse
from io import BytesIO
from datetime import datetime, timezone

REGION = os.getenv("AWS_REGION", "us-east-2")

def resolve_bucket(cli_bucket: str | None) -> str:
    # priority: CLI arg > BUCKET env > S3_BUCKET env
    bucket = (cli_bucket
              or os.getenv("BUCKET")
              or os.getenv("S3_BUCKET"))
    if not bucket or "<your-bucket>" in bucket:
        raise SystemExit(
            "BUCKET/S3_BUCKET not set (or still '<your-bucket>'). "
            "Set it to your real S3 bucket name, e.g.:\n"
            "  PowerShell:\n"
            "    $env:S3_BUCKET = \"$(terraform output -raw s3_bucket_name)\"\n"
            "  Bash:\n"
            "    export S3_BUCKET=$(terraform output -raw s3_bucket_name)\n"
        )
    return bucket

def gen_record(i:int):
    return {
        "user_id": f"user-{i%100000}",
        "timestamp": datetime.now(timezone.utc).isoformat(),  # tz-aware
        "event": "purchase" if i % 50 == 0 else "view",
        "product_id": f"sku-{i%5000}",
        "price": float((i % 200) + 0.99)
    }

def build_gz_jsonl(n_rows:int) -> bytes:
    buf = BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as gz:
        for i in range(n_rows):
            gz.write((json.dumps(gen_record(i)) + "\n").encode("utf-8"))
    return buf.getvalue()

def upload_one(s3, bucket: str, part_idx:int, rows_per_file:int, prefix:str):
    key = f"{prefix}/part-{part_idx:06d}.jsonl.gz"
    body = build_gz_jsonl(rows_per_file)
    s3.put_object(Bucket=bucket, Key=key, Body=body, ContentType="application/gzip")
    return key, len(body)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bucket", help="S3 bucket name (overrides env)")
    ap.add_argument("--rows-per-file", type=int, default=int(os.getenv("ROWS_PER_FILE", "100000")))
    ap.add_argument("--total-files", type=int, default=int(os.getenv("TOTAL_FILES", "200")))
    ap.add_argument("--workers", type=int, default=int(os.getenv("WORKERS", "16")))
    ap.add_argument("--prefix-date", help="YYYY/MM/DD (defaults to UTC today)")
    args = ap.parse_args()

    bucket = resolve_bucket(args.bucket)
    s3 = boto3.client("s3", region_name=REGION)

    date_prefix = args.prefix_date or datetime.now(timezone.utc).strftime("%Y/%m/%d")  # tz-aware
    prefix = f"ingest/{date_prefix}"

    print(f"Uploading {args.total_files} files x {args.rows_per_file} rows | prefix={prefix} | workers={args.workers} | bucket={bucket}")

    uploaded = 0
    size_sum = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = [
            ex.submit(upload_one, s3, bucket, i, args.rows_per_file, prefix)
            for i in range(args.total_files)
        ]
        for f in concurrent.futures.as_completed(futs):
            key, size_b = f.result()
            uploaded += 1
            size_sum += size_b
            if uploaded % 10 == 0:
                print(f"{uploaded}/{args.total_files} done; last={key}")

    print(f"Completed {uploaded} files; total compressed bytes ~ {size_sum:,}")

if __name__ == "__main__":
    main()




