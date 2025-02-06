# this file is used to declare a backend used during the tests

terraform {
  backend "s3" {
    encrypt = true
  }
}


# ensure  RHCS_TOKEN env variable is set with a value from https://console.redhat.com/openshift/token/rosa
# you can customize the URL using the RHCS_URL env variable
provider "rhcs" {}
