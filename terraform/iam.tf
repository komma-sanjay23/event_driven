# Assume-role policies
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Lambda execution role (shared for simplicity)
resource "aws_iam_role" "lambda_exec" {
  name               = "${var.project}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

# Basic CloudWatch logs
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Inline policy for Lambdas
data "aws_iam_policy_document" "lambda_inline" {
  statement {
    sid     = "S3RW"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.raw.arn,
      "${aws_s3_bucket.raw.arn}/*"
    ]
  }

  statement {
    sid     = "DDBWrite"
    actions = ["dynamodb:PutItem", "dynamodb:BatchWriteItem"]
    resources = [aws_dynamodb_table.activity.arn]
  }

  statement {
    sid     = "LambdaInvoke"
    actions = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.processor.arn]
  }

  # NEW: allow collector (Lambda) to start Step Function executions
  statement {
    sid     = "StepFunctionsStart"
    actions = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.pipeline.arn]
  }
}


resource "aws_iam_policy" "lambda_inline" {
  name   = "${var.project}-lambda-inline"
  policy = data.aws_iam_policy_document.lambda_inline.json
}

resource "aws_iam_role_policy_attachment" "lambda_inline_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_inline.arn
}

# Step Functions assume role policy
data "aws_iam_policy_document" "assume_sfn" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

# Step Functions role
resource "aws_iam_role" "sfn_role" {
  name               = "${var.project}-sfn-role"
  assume_role_policy = data.aws_iam_policy_document.assume_sfn.json
}

# Inline policy to allow Step Functions to invoke Lambdas
data "aws_iam_policy_document" "sfn_invoke_lambdas" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.collector.arn,
      aws_lambda_function.processor.arn,
      aws_lambda_function.transform.arn,
      aws_lambda_function.load.arn
    ]
    effect = "Allow"
  }
}

resource "aws_iam_policy" "sfn_invoke_policy" {
  name   = "${var.project}-sfn-invoke-policy"
  policy = data.aws_iam_policy_document.sfn_invoke_lambdas.json
}

resource "aws_iam_role_policy_attachment" "attach_sfn_policy" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_invoke_policy.arn
}

# Lambda execution role remains as before (lambda_exec)
