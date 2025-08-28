resource "aws_sfn_state_machine" "pipeline" {
  name     = "${var.project}-pipeline"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment = "Event-driven pipeline for user activity"
    StartAt = "Load"
    States = {
      Load = {
        Type     = "Task"
        Resource = aws_lambda_function.load.arn
        End      = true
        Parameters = {
          # Pass bucket/key directly to Lambda
          "s3_bucket.$" = "$.s3_bucket"
          "s3_key.$"    = "$.s3_key"
        }
        Retry = [
          {
            ErrorEquals     = ["States.ALL"]
            IntervalSeconds = 2
            MaxAttempts     = 1
            BackoffRate     = 2.0
          }
        ]
      }
    }
  })
}
