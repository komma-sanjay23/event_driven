# Lambda execution role
resource "aws_iam_role" "lambda_exec_role" {
  name               = "lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_access_doc" {
  statement {
    sid     = "S3Read"
    actions = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.user_data_bucket.arn,
      "${aws_s3_bucket.user_data_bucket.arn}/*"
    ]
  }
  statement {
    sid       = "DDBWrite"
    actions   = ["dynamodb:PutItem", "dynamodb:BatchWriteItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.user_events.arn]
  }
  statement {
    sid       = "LogsBasic"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
  # Orchestrator needs these:
  statement {
    sid     = "SSMGetParam"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.sfn_arn_ssm_param}"
    ]
  }
  statement {
    sid       = "SFNStartExec"
    actions   = ["states:StartExecution"]
    resources = ["*"] # you can tighten later to the single SM ARN
  }
}

resource "aws_iam_policy" "lambda_access" {
  name   = "lambda-access-managed"
  policy = data.aws_iam_policy_document.lambda_access_doc.json
}

resource "aws_iam_role_policy_attachment" "lambda_access_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_access.arn
}

# Step Functions execution role
resource "aws_iam_role" "step_function_role" {
  name               = "step-functions-role"
  assume_role_policy = data.aws_iam_policy_document.sfn_assume.json
}

data "aws_iam_policy_document" "sfn_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sfn_policy" {
  statement {
    sid       = "InvokeProcessorLambda"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.user_activity_processor.arn]
  }
  statement {
    sid = "LogsAPIAccess"
    actions = [
      "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery", "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries", "logs:PutLogEvents", "logs:CreateLogStream"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "sfn_role_policy" {
  name   = "sfn-invoke-lambda-and-logs"
  role   = aws_iam_role.step_function_role.id
  policy = data.aws_iam_policy_document.sfn_policy.json
}


