# Delete ROSA Clusters

## Description

This GitHub Action automates the deletion of ROSA (Red Hat OpenShift Service on AWS) clusters using a shell script.


## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `tf-bucket` | <p>Bucket containing the clusters states</p> | `true` | `""` |
| `tf-bucket-region` | <p>Region of the bucket containing the resources states, if not set, will fallback on AWS_REGION</p> | `false` | `""` |
| `max-age-hours-cluster` | <p>Maximum age of clusters in hours</p> | `false` | `20` |
| `rosa-cli-version` | <p>Version of the ROSA CLI to use</p> | `false` | `latest` |
| `tf-cli-config-credentials-hostname` | <p>The hostname of a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file. Defaults to <code>app.terraform.io</code>.</p> | `false` | `app.terraform.io` |
| `tf-cli-config-credentials-token` | <p>The API token for a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file.</p> | `false` | `""` |
| `tf-terraform-version` | <p>The version of Terraform CLI to install. Instead of full version string you can also specify constraint string starting with "&lt;" (for example <code>&lt;1.13.0</code>) to install the latest version satisfying the constraint. A value of <code>latest</code> will install the latest version of Terraform CLI. Defaults to <code>latest</code>.</p> | `false` | `latest` |
| `tf-terraform-wrapper` | <p>Whether or not to install a wrapper to wrap subsequent calls of the <code>terraform</code> binary and expose its STDOUT, STDERR, and exit code as outputs named <code>stdout</code>, <code>stderr</code>, and <code>exitcode</code> respectively. Defaults to <code>true</code>.</p> | `false` | `true` |
| `openshift-version` | <p>Version of the OpenShift to install</p> | `true` | `4.17.15` |
| `awscli-version` | <p>Version of the aws cli to use</p> | `true` | `2.15.52` |


## Runs

This action is a `composite` action.

## Usage

```yaml
- uses: camunda/camunda-tf-rosa/.github/actions/rosa-cleanup-clusters@main
  with:
    tf-bucket:
    # Bucket containing the clusters states
    #
    # Required: true
    # Default: ""

    tf-bucket-region:
    # Region of the bucket containing the resources states, if not set, will fallback on AWS_REGION
    #
    # Required: false
    # Default: ""

    max-age-hours-cluster:
    # Maximum age of clusters in hours
    #
    # Required: false
    # Default: 20

    rosa-cli-version:
    # Version of the ROSA CLI to use
    #
    # Required: false
    # Default: latest

    tf-cli-config-credentials-hostname:
    # The hostname of a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration
    # file. Defaults to `app.terraform.io`.
    #
    # Required: false
    # Default: app.terraform.io

    tf-cli-config-credentials-token:
    # The API token for a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration
    # file.
    #
    # Required: false
    # Default: ""

    tf-terraform-version:
    # The version of Terraform CLI to install. Instead of full version string you can also specify constraint string starting with "<" (for
    # example `<1.13.0`) to install the latest version satisfying the constraint. A value of `latest` will install the latest version of Terraform
    # CLI. Defaults to `latest`.
    #
    # Required: false
    # Default: latest

    tf-terraform-wrapper:
    # Whether or not to install a wrapper to wrap subsequent calls of the `terraform` binary and expose its STDOUT, STDERR, and exit code
    # as outputs named `stdout`, `stderr`, and `exitcode` respectively. Defaults to `true`.
    #
    # Required: false
    # Default: true

    openshift-version:
    # Version of the OpenShift to install
    #
    # Required: true
    # Default: 4.17.15

    awscli-version:
    # Version of the aws cli to use
    #
    # Required: true
    # Default: 2.15.52
```
