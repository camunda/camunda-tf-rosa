# this file is used to declare a backend used during the tests

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.35.0"
    }
    rhcs = {
      version = "1.6.6"
      source  = "terraform-redhat/rhcs"
    }
  }

  backend "s3" {
    encrypt = true
  }
}


# ensure  RHCS_TOKEN env variable is set with a value from https://console.redhat.com/openshift/token/rosa
# you can customize the URL using the RHCS_URL env variable
provider "rhcs" {}
