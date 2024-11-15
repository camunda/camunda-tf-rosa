provider "rhcs" {
  token = var.offline_access_token
  url   = var.url
}

data "aws_caller_identity" "current" {}
