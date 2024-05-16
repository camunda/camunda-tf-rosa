# Delete ROSA HCP Cluster GitHub Action

This GitHub Action automates the deletion of a ROSA (Red Hat OpenShift Service on AWS) cluster using Terraform. It also installs `awscli`.

## Inputs

| Input                | Description                                              | Required | Default                        |
|----------------------|----------------------------------------------------------|----------|--------------------------------|
| `rh-token`           | Red Hat Hybrid Cloud Console Token                       | true     |                                |
| `cluster-name`       | Name of the ROSA cluster to delete                       | true     |                                |
| `aws-region`         | AWS region where the ROSA cluster is deployed            | true     |                                |
| `s3-backend-bucket`  | Name of the S3 bucket where the Terraform state is stored| true     |                                |
| `awscli-version`     | Version of the aws cli to use                            | true     | `1.32.105`                     |
| `tf-modules-revision`| Git revision of the tf modules to use                    | true     | `main`                         |
| `tf-modules-path`    | Path where the tf rosa modules will be cloned            | true     | `./.action-tf-modules/rosa/`   |

## Usage

Create a file in your repository's `.github/workflows` directory, for example `delete-rosa-hcp.yml`, with the following content:

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
        with:
          rh-token: ${{ secrets.RH_OPENSHIFT_TOKEN }}
          cluster-name: "my-ocp-cluster"
          aws-region: "us-west-2"
          s3-backend-bucket: ${{ secrets.TF_S3_BUCKET }}
          awscli-version: "1.32.105"
          tf-modules-revision: "main"
          tf-modules-path: "./.action-tf-modules/rosa/"
```