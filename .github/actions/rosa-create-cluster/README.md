# Deploy ROSA HCP Cluster GitHub Action

This GitHub Action automates the deployment of a ROSA (Red Hat OpenShift Service on AWS) cluster using Terraform. It also installs `oc`, `awscli`, and `rosa` CLI tools.

## Inputs

| Input               | Description                                                  | Required | Default          |
|---------------------|--------------------------------------------------------------|----------|------------------|
| `rh-token`          | Red Hat Hybrid Cloud Console Token                           | true     |                  |
| `cluster-name`      | Name of the ROSA cluster to deploy                           | true     |                  |
| `admin-password`    | Admin password for the ROSA cluster                          | true     |                  |
| `admin-username`    | Admin username for the ROSA cluster                          | false    | `cluster-admin`  |
| `aws-region`        | AWS region where the ROSA cluster will be deployed           | true     |                  |
| `rosa-cli-version`  | Version of the ROSA CLI to use                               | false    | `latest`         |
| `awscli-version`    | Version of the AWS CLI to use                                | false    | `1.32.105`       |
| `openshift-version` | Version of the OpenShift to install                          | false    | `4.15.11`        |
| `replicas`          | Number of replicas for the ROSA cluster                      | false    | `2`              |
| `s3-backend-bucket` | Name of the S3 bucket to store Terraform state               | true     |                  |
| `tf-modules-revision`| Git revision of the Terraform modules to use                | false    | `main`           |
| `tf-modules-path`   | Path where the Terraform ROSA modules will be cloned         | false    | `./.action-tf-modules/rosa/` |
| `login`             | Authenticate the current kube context on the created cluster | false    | `true`           |
| `tf-cli-config-credentials-hostname` | The hostname of a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file. Defaults to `app.terraform.io`. | false | `app.terraform.io` |
| `tf-cli-config-credentials-token` | The API token for a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file. | false | |
| `tf-terraform-version`     | The version of Terraform CLI to install. Defaults to `latest`.                 | false    | `latest`         |
| `tf-terraform-wrapper`     | Whether or not to install a wrapper to wrap subsequent calls of the `terraform` binary and expose its STDOUT, STDERR, and exit code as outputs named `stdout`, `stderr`, and `exitcode` respectively. Defaults to `true`. | false | `true` |

## Outputs

| Output                   | Description                                                |
|--------------------------|------------------------------------------------------------|
| `openshift-server-api`   | The server API URL of the deployed ROSA cluster            |
| `openshift-cluster-id`   | The ID of the deployed ROSA cluster                        |
| `terraform-state-url`    | URL of the Terraform state file in the S3 bucket            |

## Usage

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
        with:
          rh-token: ${{ secrets.RH_OPENSHIFT_TOKEN }}
          cluster-name: "my-ocp-cluster"
          admin-username: "cluster-admin"
          admin-password: ${{ secrets.CI_OPENSHIFT_MAIN_PASSWORD }}
          aws-region: "us-west-2"
          namespace: "myns"
          s3-backend-bucket: ${{ secrets.TF_S3_BUCKET }}

      - name: Generate kubeconfig
        uses: nick-fields/retry@v3
        id: kube_config
        with:
          timeout_minutes: 10
          max_attempts: 40
          shell: bash
          retry_wait_seconds: 15
          command: |
            oc login --username "cluster-admin" --password ${{ secrets.CI_OPENSHIFT_MAIN_PASSWORD }} "${{ steps.create_cluster.outputs.openshift-server-api }}"
            oc whoami

            kubectl config rename-context $(oc config current-context) "my-ocp-cluster"
            kubectl config use "my-ocp-cluster"
```