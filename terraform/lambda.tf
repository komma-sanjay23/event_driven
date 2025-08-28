# -----------------------------
# Ensure .build folder exists
# -----------------------------
resource "null_resource" "build_dir" {
  provisioner "local-exec" {
    command     = "if (-Not (Test-Path -Path ${path.module}\\.build)) { New-Item -ItemType Directory -Path ${path.module}\\.build }"
    interpreter = ["PowerShell", "-Command"]
  }

  triggers = {
    always_run = timestamp()
  }
}

# -----------------------------
# Package Lambdas from source files
# -----------------------------
data "archive_file" "collector_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/collector.py"
  output_path = "${path.module}/.build/collector.zip"

  depends_on = [null_resource.build_dir]
}

data "archive_file" "processor_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/processor.py"
  output_path = "${path.module}/.build/processor.zip"

  depends_on = [null_resource.build_dir]
}

# -----------------------------
# Collector Lambda
# -----------------------------
resource "aws_lambda_function" "collector" {
  function_name = "${var.project}-collector"
  handler       = "collector.handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 15
  memory_size   = 128

  filename         = data.archive_file.collector_zip.output_path
  source_code_hash = data.archive_file.collector_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME       = aws_s3_bucket.raw.bucket
      STATE_MACHINE_ARN = aws_sfn_state_machine.pipeline.arn
    }
  }

  depends_on = [null_resource.build_dir]
}

# -----------------------------
# Processor Lambda
# -----------------------------
resource "aws_lambda_function" "processor" {
  function_name = "${var.project}-processor"
  handler       = "processor.handler"  # Make sure this matches your processor.py handler
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.processor_zip.output_path
  source_code_hash = data.archive_file.processor_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.raw.bucket
      TABLE_NAME  = aws_dynamodb_table.activity.name
    }
  }

  depends_on = [null_resource.build_dir]
}

# -----------------------------
# Transform Lambda
# -----------------------------
resource "aws_lambda_function" "transform" {
  function_name = "${var.project}-transform"
  handler       = "processor.handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.processor_zip.output_path
  source_code_hash = data.archive_file.processor_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.activity.name
    }
  }
}

# -----------------------------
# Load Lambda
# -----------------------------
resource "aws_lambda_function" "load" {
  function_name = "${var.project}-load"
  handler       = "processor.handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 180
  memory_size   = 1024

  filename         = data.archive_file.processor_zip.output_path
  source_code_hash = data.archive_file.processor_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.activity.name
    }
  }
}

# -----------------------------
# S3 → Collector Lambda permission
# -----------------------------
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collector.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw.arn
}

# -----------------------------
# Single merged S3 bucket notification
# -----------------------------
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.collector.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "ingest/"
    filter_suffix       = ".jsonl"
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# -----------------------------
# IAM: allow collector to start Step Functions
# -----------------------------
resource "aws_iam_policy" "collector_sfn" {
  name   = "${var.project}-collector-sfn"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["states:StartExecution"]
        Resource = aws_sfn_state_machine.pipeline.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "collector_sfn_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.collector_sfn.arn
}
