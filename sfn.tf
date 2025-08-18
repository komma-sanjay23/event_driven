resource "aws_sfn_state_machine" "user_activity_pipeline" {
  name     = "UserActivityPipeline"
  role_arn = aws_iam_role.step_function_role.arn

  logging_configuration {
    include_execution_data = false
    level                  = "ERROR"
    log_destination        = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
  }

  tracing_configuration {
    enabled = true
  }

  # Task -> (Next) MarkSucceeded
  #        \-(Catch ALL)-> MarkFailed
  definition = jsonencode({
    Comment = "Process one S3 object with success/fail branches"
    StartAt = "ProcessObject"
    States = {
      ProcessObject = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.user_activity_processor.arn
          Payload = {
            "bucket.$" = "$.bucket"
            "key.$"    = "$.key"
          }
        }
        ResultPath = "$.processor" # keep Lambda result if you want; remove if not needed
        Retry = [
          {
            ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "States.TaskFailed"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "MarkFailed"
          }
        ]
        Next = "MarkSucceeded"
      }

      MarkSucceeded = { Type = "Succeed" }

      MarkFailed = {
        Type  = "Fail"
        Error = "ProcessingFailed"
        Cause = "Processor Lambda threw an error or returned a failure."
      }
    }
  })
}




