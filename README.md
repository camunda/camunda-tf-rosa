# Camunda Terraform Red Hat OpenShift on AWS Modules

[![Camunda](https://img.shields.io/badge/Camunda-FC5D0D)](https://www.camunda.com/)
[![tests](https://github.com/camunda/camunda-tf-rosa/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/camunda/camunda-tf-rosa/actions/workflows/tests.yml)
[![License](https://img.shields.io/github/license/camunda/camunda-tf-rosa)](LICENSE)

This module automates the creation of a ROSA HCP cluster with an opinionated configuration targeting Camunda 8 on AWS using Terraform.

**⚠️ Warning:** This project is not intended for production use but rather for demonstration purposes only. There are no guarantees or warranties provided.

For more detailed usage and configuration options, please refer to the module's inputs and outputs documentation below.

## Requirements

To gather all specifics versions of this project, we use:
- [asdf](https://asdf-vm.com/) version manager (see [installation](https://asdf-vm.com/guide/getting-started.html)).
- [just](https://github.com/casey/just) as a command runner
  - install it using asdf: `asdf plugin add just && asdf install just`

Then we will install all the tooling listed in the `.tool-versions` of this root project using just:
```bash
just install-tooling

# list available recipes
just --list
```

* Terraform (installed by asdf)
* AWS CLI (installed by asdf)
* ROSA CLI ([installation guide](https://docs.openshift.com/rosa/rosa_install_access_delete_clusters/rosa_getting_started_iam/rosa-installing-rosa.html))
* OpenShift CLI ([installation guide](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html))

## Getting started : Create a ROSA HCP cluster

Base tutorial https://aws.amazon.com/blogs/containers/build-rosa-clusters-with-terraform/

### I. Enable ROSA in AWS Marketplace

1. Login onto AWS
2. Check if ELB role exists
```bash
# To check if the role exists for your account, run this command in your terminal:
aws iam get-role --role-name "AWSServiceRoleForElasticLoadBalancing"

# If the role doesn't exist, create it by running the following command:
aws iam create-service-linked-role --aws-service-name "elasticloadbalancing.amazonaws.com"

```
3. Login onto [Red Hat Hybrid Cloud Console](https://console.redhat.com/openshift/token)
4. Generate an Offline token, click on "Load Token"
```bash
export RH_TOKEN=yourToken
rosa login --token=${RH_TOKEN}

rosa whoami

rosa verify quota --region="$AWS_REGION"

# this may fail due to org policy
rosa verify permissions --region="$AWS_REGION"

rosa create account-roles --mode auto
```
5. Enable HCP ROSA on [AWS MarkePlace](https://docs.openshift.com/rosa/cloud_experts_tutorials/cloud-experts-rosa-hcp-activation-and-account-linking-tutorial.html)
    * Navigate to the ROSA console : https://console.aws.amazon.com/rosa
    * Choose Get started.
    * On the Verify ROSA prerequisites page, select I agree to share my contact information with Red Hat.
    * Choose Enable ROSA

Please note that **Only a single AWS account that will be used for service billing can be associated with a Red Hat account.**

### II. Create the cluster

#### Terraform

To use this module with Terraform, follow these steps:

1. **Create a Terraform configuration file** (e.g., `main.tf`).
2. **Include the ROSA HCP module** in your configuration file.

Here's an example configuration:

```hcl
module "rosa_hcp" {
  source = "github.com/camunda/camunda-tf-rosa.git//modules/rosa-hcp?ref=main"

  cluster_name           = "my-ocp-cluster"
  htpasswd_password      = "your_password"
  offline_access_token   = "your_ocm_token" # see below for instructions
  openshift_version      = "4.15.11"
  replicas               = "2"
}
```

For more details, refer to the [Terraform module ROSA HCP README](https://github.com/camunda/camunda-tf-rosa/blob/main/modules/rosa-hcp/README.md).


3. **Initialize Terraform** by running:
    ```sh
    terraform init
    ```

4. **Review the execution plan** with:
    ```sh
    terraform plan
    ```

5. **Apply the configuration** to create the resources:
    ```sh
    terraform apply
    ```

#### GitHub Actions

You can automate the deployment and deletion of the ROSA HCP cluster using GitHub Actions. Below are examples of GitHub Actions workflows for deploying and deleting the cluster.

##### Deploy ROSA HCP Cluster

Create a file in your repository's `.github/workflows` directory, for example `deploy-rosa-hcp.yml`, with the following content:

```yaml
name: Deploy ROSA HCP Cluster

on:
  pull_request:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Add profile credentials to ~/.aws/credentials
        run: |
          aws configure set aws_access_key_id ${{ secrets.AWS_ACCESS_KEY }} --profile ${{ env.AWS_PROFILE }}
          aws configure set aws_secret_access_key ${{ secrets.AWS_SECRET_KEY }} --profile ${{ env.AWS_PROFILE }}
          aws configure set region ${{ env.AWS_REGION }} --profile ${{ env.AWS_PROFILE }}

      - name: Deploy ROSA HCP Cluster
        uses: camunda/camunda-tf-rosa/.github/actions/rosa-create-cluster@main
        id: create_cluster
        timeout-minutes: 125 # cluster creation can take up to 45 minutes
        with:
          rh-token: ${{ secrets.RH_OPENSHIFT_TOKEN }}
          cluster-name: "my-ocp-cluster"
          admin-username: "kube-admin"
          admin-password: ${{ secrets.CI_OPENSHIFT_MAIN_PASSWORD }}
          aws-region: "us-west-2"
          s3-backend-bucket: ${{ secrets.TF_S3_BUCKET }}

      - name: Use your created cluster
        shell: bash
        run: |
          oc new-project "myns"
          oc whoami
          oc get pods
```

For more details, refer to the [Deploy ROSA HCP Cluster Action README](https://github.com/camunda/camunda-tf-rosa/blob/main/.github/actions/rosa-create-cluster/README.md).

##### Delete ROSA HCP Cluster

Create another file in your repository's `.github/workflows` directory, for example `delete-rosa-hcp.yml`, with the following content:

```yaml
name: Delete ROSA HCP Cluster

on:
  workflow_dispatch:

jobs:
  delete:
    runs-on: ubuntu-latest
    steps:
      - name: Delete ROSA HCP Cluster
        uses: camunda/camunda-tf-rosa/.github/actions/rosa-delete-cluster@main
        timeout-minutes: 125 # cluster deletion can take some time
        with:
          rh-token: ${{ secrets.RH_OPENSHIFT_TOKEN }}
          cluster-name: "my-ocp-cluster"
          aws-region: "us-west-2"
          s3-backend-bucket: ${{ secrets.TF_S3_BUCKET }}
```

For more details, refer to the [Delete ROSA HCP Cluster Action README](https://github.com/camunda/camunda-tf-rosa/blob/main/.github/actions/rosa-delete-cluster/README.md).


### III. Retrieve cluster informations

1. In the output, you will have the created cluster id:
```bash
cluster_id = "2b3sq2r4geb7b6htaibb4uqk9qc9c3fa"
```
2. Describe the cluster
```bash
export CLUSTER_ID="2b3sq2r4geb7b6htaibb4uqk9qc9c3fa"

rosa describe cluster --output=json -c $CLUSTER_ID
```
3. Generate the kubeconfig:
```bash
export NAMESPACE="myNs"
export SERVER_API=$(rosa describe cluster --output=json -c "$CLUSTER_ID" | jq -r '.api.url')
oc login --username "$ADMIN_USER" --password "$ADMIN_PASS" --server=$SERVER_API

kubectl config rename-context $(oc config current-context) "$CLUSTER_NAME"
kubectl config use "$CLUSTER_NAME"

# create a new project
oc new-project "$NAMESPACE"
```

## Support

Please note that the modules have been tested with **[Terraform](https://github.com/hashicorp/terraform)** in the version described in the [.tool-versions](./.tool-versions) of this project.
