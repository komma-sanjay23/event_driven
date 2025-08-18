resource "aws_cloudwatch_log_group" "sfn_logs" {
  name              = "/aws/states/user-activity-pipeline"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_resource_policy" "sfn_logs_policy" {
  policy_name = "AllowStepFunctionsToWriteLogs"
  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowStepFunctionsLogging",
      Effect    = "Allow",
      Principal = { Service = "states.amazonaws.com" },
      Action = [
        "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery",
        "logs:DeleteLogDelivery", "logs:ListLogDeliveries", "logs:PutLogEvents", "logs:CreateLogStream"
      ],
      Resource = "*"
    }]
  })
}

# Alarm: any SFN failure > 0
resource "aws_cloudwatch_metric_alarm" "sfn_failed" {
  alarm_name          = "UserActivityPipeline-ExecutionsFailed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.user_activity_pipeline.arn
  }
}



