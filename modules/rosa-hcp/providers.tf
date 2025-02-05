data "aws_caller_identity" "current" {}

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    rhcs = {
      source = "terraform-redhat/rhcs"
    }
  }
}
