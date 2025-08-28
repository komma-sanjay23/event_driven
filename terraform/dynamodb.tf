resource "aws_dynamodb_table" "activity" {
  name         = "${var.project}-table"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "user_id"
  range_key = "event_ts"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "event_ts"
    type = "S"
  }
}
