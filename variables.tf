variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-east-2"
}

variable "s3_bucket_name" {
  description = "Bucket to store user activity files"
  type        = string
  default     = "user-activity-bucket-demo-1234" # change to a unique name
}

variable "dynamodb_table_name" {
  description = "DynamoDB table for processed events"
  type        = string
  default     = "user-events"
}

variable "sfn_arn_ssm_param" {
  description = "SSM parameter path to store SFN ARN"
  type        = string
  default     = "/pipelines/user-activity/stateMachineArn"
}


# variable "cloudwatch_lambda_log_group_name" {
#   description = "Log group name for Lambda (optional manual create)"
#   type        = string
#   default     = "/aws/lambda/user-activity-processor"
# }




