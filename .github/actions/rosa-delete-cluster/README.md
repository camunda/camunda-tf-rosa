# Delete ROSA HCP Cluster

## Description

This GitHub Action automates the deletion of a ROSA (Red Hat OpenShift Service on AWS) cluster using Terraform.
This action will also install awscli.


## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `rh-token` | <p>Red Hat Hybrid Cloud Console Token</p> | `true` | `""` |
| `cluster-name` | <p>Name of the ROSA cluster to delete</p> | `true` | `""` |
| `aws-region` | <p>AWS region where the ROSA cluster is deployed</p> | `true` | `""` |
| `s3-backend-bucket` | <p>Name of the S3 bucket where the Terraform state is stored</p> | `true` | `""` |
| `s3-bucket-region` | <p>Region of the bucket containing the resources states, if not set, will fallback on aws-region</p> | `false` | `""` |
| `awscli-version` | <p>Version of the aws cli to use</p> | `true` | `2.15.52` |
| `tf-modules-revision` | <p>Git revision of the tf modules to use</p> | `true` | `main` |
| `tf-modules-path` | <p>Path where the tf rosa modules will be cloned</p> | `true` | `./.action-tf-modules/rosa/` |
| `tf-cli-config-credentials-hostname` | <p>The hostname of a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file. Defaults to <code>app.terraform.io</code>.</p> | `false` | `app.terraform.io` |
| `tf-cli-config-credentials-token` | <p>The API token for a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file.</p> | `false` | `""` |
| `tf-terraform-version` | <p>The version of Terraform CLI to install. Instead of full version string you can also specify constraint string starting with "&lt;" (for example <code>&lt;1.13.0</code>) to install the latest version satisfying the constraint. A value of <code>latest</code> will install the latest version of Terraform CLI. Defaults to <code>latest</code>.</p> | `false` | `latest` |
| `tf-terraform-wrapper` | <p>Whether or not to install a wrapper to wrap subsequent calls of the <code>terraform</code> binary and expose its STDOUT, STDERR, and exit code as outputs named <code>stdout</code>, <code>stderr</code>, and <code>exitcode</code> respectively. Defaults to <code>true</code>.</p> | `false` | `true` |


## Runs

This action is a `composite` action.

## Usage

```yaml
- uses: camunda/camunda-tf-rosa/.github/actions/rosa-delete-cluster@main
  with:
    rh-token:
    # Red Hat Hybrid Cloud Console Token
    #
    # Required: true
    # Default: ""

    cluster-name:
    # Name of the ROSA cluster to delete
    #
    # Required: true
    # Default: ""

    aws-region:
    # AWS region where the ROSA cluster is deployed
    #
    # Required: true
    # Default: ""

    s3-backend-bucket:
    # Name of the S3 bucket where the Terraform state is stored
    #
    # Required: true
    # Default: ""

    s3-bucket-region:
    # Region of the bucket containing the resources states, if not set, will fallback on aws-region
    #
    # Required: false
    # Default: ""

    awscli-version:
    # Version of the aws cli to use
    #
    # Required: true
    # Default: 2.15.52

    tf-modules-revision:
    # Git revision of the tf modules to use
    #
    # Required: true
    # Default: main

    tf-modules-path:
    # Path where the tf rosa modules will be cloned
    #
    # Required: true
    # Default: ./.action-tf-modules/rosa/

    tf-cli-config-credentials-hostname:
    # The hostname of a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file. Defaults to `app.terraform.io`.
    #
    # Required: false
    # Default: app.terraform.io

    tf-cli-config-credentials-token:
    # The API token for a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file.
    #
    # Required: false
    # Default: ""

    tf-terraform-version:
    # The version of Terraform CLI to install. Instead of full version string you can also specify constraint string starting with "<" (for example `<1.13.0`) to install the latest version satisfying the constraint. A value of `latest` will install the latest version of Terraform CLI. Defaults to `latest`.
    #
    # Required: false
    # Default: latest

    tf-terraform-wrapper:
    # Whether or not to install a wrapper to wrap subsequent calls of the `terraform` binary and expose its STDOUT, STDERR, and exit code as outputs named `stdout`, `stderr`, and `exitcode` respectively. Defaults to `true`.
    #
    # Required: false
    # Default: true
```
