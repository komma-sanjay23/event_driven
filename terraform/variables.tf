variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-2"
}

variable "project" {
  type        = string
  description = "Project name prefix"
  default     = "user-activity-pipeline"
}
