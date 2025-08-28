provider "aws" {
  region = var.aws_region
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.project}-raw-${random_id.suffix.hex}"
}
