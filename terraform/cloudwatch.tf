# One alarm per Lambda for clarity
resource "aws_cloudwatch_metric_alarm" "collector_errors" {
  alarm_name          = "${var.project}-collector-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  dimensions = { FunctionName = aws_lambda_function.collector.function_name }
}

resource "aws_cloudwatch_metric_alarm" "transform_errors" {
  alarm_name          = "${var.project}-transform-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  dimensions = { FunctionName = aws_lambda_function.transform.function_name }
}

resource "aws_cloudwatch_metric_alarm" "load_errors" {
  alarm_name          = "${var.project}-load-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  dimensions = { FunctionName = aws_lambda_function.load.function_name }
}

resource "aws_cloudwatch_metric_alarm" "sfn_failed" {
  alarm_name          = "${var.project}-sfn-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  dimensions = { StateMachineArn = aws_sfn_state_machine.pipeline.arn }
}
