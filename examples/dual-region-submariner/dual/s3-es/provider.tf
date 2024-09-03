################################
# Backend & Provider Setup    #
################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.51.1"
    }
  }

  backend "s3" {}
}
provider "aws" {
}
