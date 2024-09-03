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

# Two provider configurations are needed to create resources in two different regions
# It's a limitation by how the AWS provider works
provider "aws" {
  region = var.owner.region
}

provider "aws" {
  region = var.accepter.region
  alias  = "accepter"
}
