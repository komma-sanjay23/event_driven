# Package lambdas
data "archive_file" "orchestrator_package" {
  type        = "zip"
  source_file = "${path.module}/lambdas/orchestrator.py"
  output_path = "${path.module}/lambdas/orchestrator.zip"
}

data "archive_file" "data_processor_package" {
  type        = "zip"
  source_file = "${path.module}/lambdas/data_processor.py"
  output_path = "${path.module}/lambdas/data_processor.zip"
}

# Orchestrator Lambda (triggered by S3 object created)
resource "aws_lambda_function" "orchestrator" {
  function_name = "user-activity-orchestrator"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "orchestrator.lambda_handler"
  runtime       = "python3.10"

  filename         = data.archive_file.orchestrator_package.output_path
  source_code_hash = filebase64sha256(data.archive_file.orchestrator_package.output_path)

  timeout = 30

  environment {
    variables = {
      SFN_ARN_PARAM = var.sfn_arn_ssm_param
    }
  }

  tags = { Name = "user-activity-orchestrator", Environment = "dev" }
}

# Allow S3 to invoke orchestrator
resource "aws_lambda_permission" "orchestrator_allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.user_data_bucket.arn
}

# S3 -> Lambda event
resource "aws_s3_bucket_notification" "s3_to_orchestrator" {
  bucket = aws_s3_bucket.user_data_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.orchestrator.arn
    events              = ["s3:ObjectCreated:*"]
    # filter_prefix       = "ingest/"     # uncomment if you want to scope
    # filter_suffix       = ".jsonl.gz"   # uncomment if you want to scope
  }

  depends_on = [aws_lambda_permission.orchestrator_allow_s3]
}

# Processor Lambda (invoked by Step Functions)
resource "aws_lambda_function" "user_activity_processor" {
  function_name = "user-activity-processor"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "data_processor.lambda_handler"
  runtime       = "python3.10"

  filename         = data.archive_file.data_processor_package.output_path
  source_code_hash = filebase64sha256(data.archive_file.data_processor_package.output_path)

  memory_size = 3008
  timeout     = 30

  environment {
    variables = {
      DDB_TABLE = aws_dynamodb_table.user_events.name
    }
  }

  tags = { Name = "user-activity-processor", Environment = "dev" }
}


