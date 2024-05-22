# Delete ROSA HCP Cluster GitHub Action

This GitHub Action automates the deletion of a ROSA (Red Hat OpenShift Service on AWS) cluster using Terraform. It also installs `awscli`.

## Inputs

| Input                | Description                                              | Required | Default                        |
|----------------------|----------------------------------------------------------|----------|--------------------------------|
| `rh-token`           | Red Hat Hybrid Cloud Console Token                       | true     |                                |
| `cluster-name`       | Name of the ROSA cluster to delete                       | true     |                                |
| `aws-region`         | AWS region where the ROSA cluster is deployed            | true     |                                |
| `s3-backend-bucket`  | Name of the S3 bucket where the Terraform state is stored| true     |                                |
| `awscli-version`     | Version of the aws cli to use                            | false    | __see `action.yml`__                      |
| `tf-modules-revision`| Git revision of the tf modules to use                    | false    | `main`                         |
| `tf-modules-path`    | Path where the tf rosa modules will be cloned            | false    | `./.action-tf-modules/rosa/`   |
| `tf-cli-config-credentials-hostname` | The hostname of a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file. Defaults to `app.terraform.io`. | false | `app.terraform.io` |
| `tf-cli-config-credentials-token` | The API token for a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file. | false | |
| `tf-terraform-version`     | The version of Terraform CLI to install. Defaults to `latest`.                 | false    | `latest`         |
| `tf-terraform-wrapper`     | Whether or not to install a wrapper to wrap subsequent calls of the `terraform` binary and expose its STDOUT, STDERR, and exit code as outputs named `stdout`, `stderr`, and `exitcode` respectively. Defaults to `true`. | false | `true` |

## Usage

For this destruction action, it is not necessary to have called the creation action just before, as the state will be retrieved via the bucket.

Create a file in your repository's `.github/workflows` directory, for example `delete-rosa-hcp.yml`, with the following content:

```yaml
name: Delete ROSA HCP Cluster

on:
  pull_request:

jobs:
  delete:
    runs-on: ubuntu-latest
    steps:
      - name: Delete ROSA HCP Cluster
        uses: camunda/camunda-tf-rosa/.github/actions/rosa-delete-cluster@main
        with:
          rh-token: ${{ secrets.RH_OPENSHIFT_TOKEN }}
          cluster-name: "my-ocp-cluster"
          aws-region: "us-west-2"
          s3-backend-bucket: ${{ secrets.TF_S3_BUCKET }}
```
