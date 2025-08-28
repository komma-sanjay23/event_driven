# generator.py
import os
import json
import uuid
import random
import string
import tempfile
import boto3
import concurrent.futures
from datetime import datetime, timedelta
from botocore.exceptions import BotoCoreError, ClientError

# ======= CONFIG =======
AWS_REGION    = os.getenv("AWS_REGION", "us-east-2")
S3_BUCKET     = os.getenv("S3_BUCKET")          # required
S3_PREFIX     = os.getenv("S3_PREFIX", "ingest/")
TEST_MODE     = os.getenv("TEST_MODE", "False").lower() == "true"

TOTAL_SIZE_GB = 0.001 if TEST_MODE else 5
CHUNK_SIZE_MB = 1 if TEST_MODE else 20   # smaller chunks for safety
MAX_WORKERS   = 2       # concurrent uploads
MAX_RETRIES   = 3
# ======================

random.seed(42)
s3 = boto3.client("s3", region_name=AWS_REGION)

def rand_str(n=12):
    return "".join(random.choices(string.ascii_letters + string.digits, k=n))

def make_event(base_time: datetime):
    return {
        "user_id": str(uuid.uuid4()),
        "action": random.choice(["page_view", "click", "purchase", "scroll", "logout"]),
        "event_ts": (base_time + timedelta(seconds=random.randint(0, 3600*24))).isoformat() + "Z",
        "metadata": {"page": f"/{rand_str(6)}", "ref": rand_str(8)},
        "version": 1,
    }

def write_chunk_to_file(target_bytes: int, base_time: datetime):
    with tempfile.NamedTemporaryFile("w", delete=False) as tmp:
        path = tmp.name
        written = 0
        while written < target_bytes:
            ev = make_event(base_time)
            line = json.dumps(ev, separators=(",", ":")) + "\n"
            tmp.write(line)
            written += len(line.encode("utf-8"))
    return path, written

def upload_file_with_retry(local_path: str, key: str, retries=MAX_RETRIES):
    for attempt in range(1, retries + 1):
        try:
            s3.upload_file(local_path, S3_BUCKET, key)
            os.remove(local_path)
            print(f"[OK] Uploaded {key}")
            return True, f"Uploaded {key}"
        except (BotoCoreError, ClientError) as e:
            print(f"[WARN] Attempt {attempt}/{retries} failed for {key}: {e}")
            if attempt == retries:
                return False, f"FAILED {key}: {e}"
    return False, f"FAILED {key}: Unknown error"

def main():
    if not S3_BUCKET:
        raise ValueError("S3_BUCKET not set. Export it from terraform output.")

    total_bytes_target = TOTAL_SIZE_GB * (1024 ** 3)
    chunk_bytes_target = CHUNK_SIZE_MB * (1024 ** 2)
    base_time = datetime.utcnow()

    print(f"Generating ~{TOTAL_SIZE_GB} GB in ~{CHUNK_SIZE_MB} MB chunks "
          f"to s3://{S3_BUCKET}/{S3_PREFIX} with {MAX_WORKERS} workers")

    file_idx = 0
    bytes_done = 0
    results = []

    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        in_flight = []

        while bytes_done < total_bytes_target:
            file_idx += 1
            key = f"{S3_PREFIX}part-{file_idx:05d}.jsonl"
            path, wrote = write_chunk_to_file(chunk_bytes_target, base_time)
            bytes_done += wrote

            future = executor.submit(upload_file_with_retry, path, key)
            in_flight.append(future)

            if len(in_flight) >= MAX_WORKERS:
                done, _ = concurrent.futures.wait(in_flight, return_when=concurrent.futures.FIRST_COMPLETED)
                for d in done:
                    success, msg = d.result()
                    results.append((success, msg))
                    in_flight.remove(d)

        for future in concurrent.futures.as_completed(in_flight):
            success, msg = future.result()
            results.append((success, msg))

    failed = [msg for success, msg in results if not success]
    print("\n=== Summary ===")
    print(f"Total files attempted: {len(results)}")
    print(f"Failed uploads: {len(failed)}")
    if failed:
        print("Failures:")
        for f in failed:
            print(f"  {f}")
    else:
        print("All uploads succeeded 🎉")

if __name__ == "__main__":
    main()
