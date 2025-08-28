output "collector_lambda_name" { 
    value = aws_lambda_function.collector.function_name 
 }

output "state_machine_arn"     { 
    value = aws_sfn_state_machine.pipeline.arn 
 }

output "s3_bucket"             { 
    value = aws_s3_bucket.raw.bucket 
 }

output "dynamodb_table"        { 
    value = aws_dynamodb_table.activity.name
 }
