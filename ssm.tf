resource "aws_ssm_parameter" "sfn_arn" {
  name  = var.sfn_arn_ssm_param
  type  = "String"
  value = aws_sfn_state_machine.user_activity_pipeline.arn
}


