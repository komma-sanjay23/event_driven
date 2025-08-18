output "s3_bucket_name" {
  value = aws_s3_bucket.user_data_bucket.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.user_events.name
}

output "lambda_exec_role_arn" {
  value = aws_iam_role.lambda_exec_role.arn
}

output "processor_lambda_arn" {
  value = aws_lambda_function.user_activity_processor.arn
}

output "sfn_role_arn" {
  value = aws_iam_role.step_function_role.arn
}

output "sfn_arn" {
  value = aws_sfn_state_machine.user_activity_pipeline.arn
}

output "sfn_log_group_arn" {
  value = "${aws_cloudwatch_log_group.sfn_logs.arn}:*"
}



