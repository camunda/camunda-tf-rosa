# Deploy ROSA HCP Cluster

## Description

This GitHub Action automates the deployment of a ROSA (Red Hat OpenShift Service on AWS) cluster using Terraform.
This action will also install oc, awscli, rosa cli.
The kube context will be set on the created cluster.


## Inputs

| name | description | required | default |
| --- | --- | --- | --- |
| `rh-token` | <p>Red Hat Hybrid Cloud Console Token</p> | `true` | `""` |
| `cluster-name` | <p>Name of the ROSA cluster to deploy</p> | `true` | `""` |
| `admin-password` | <p>Admin password for the ROSA cluster</p> | `true` | `""` |
| `admin-username` | <p>Admin username for the ROSA cluster</p> | `true` | `kube-admin` |
| `aws-region` | <p>AWS region where the ROSA cluster will be deployed</p> | `true` | `""` |
| `rosa-cli-version` | <p>Version of the ROSA CLI to use</p> | `true` | `latest` |
| `awscli-version` | <p>Version of the aws cli to use</p> | `true` | `2.15.52` |
| `openshift-version` | <p>Version of the OpenShift to install</p> | `true` | `4.16.10` |
| `replicas` | <p>Number of replicas for the ROSA cluster</p> | `true` | `2` |
| `s3-backend-bucket` | <p>Name of the S3 bucket to store Terraform state</p> | `true` | `""` |
| `s3-bucket-region` | <p>Region of the bucket containing the resources states, if not set, will fallback on aws-region</p> | `false` | `""` |
| `tf-modules-revision` | <p>Git revision of the tf modules to use</p> | `true` | `main` |
| `tf-modules-path` | <p>Path where the tf rosa modules will be cloned</p> | `true` | `./.action-tf-modules/rosa/` |
| `login` | <p>Authenticate the current kube context on the created cluster</p> | `true` | `true` |
| `tf-cli-config-credentials-hostname` | <p>The hostname of a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file. Defaults to <code>app.terraform.io</code>.</p> | `false` | `app.terraform.io` |
| `tf-cli-config-credentials-token` | <p>The API token for a HCP Terraform/Terraform Enterprise instance to place within the credentials block of the Terraform CLI configuration file.</p> | `false` | `""` |
| `tf-terraform-version` | <p>The version of Terraform CLI to install. Instead of full version string you can also specify constraint string starting with "&lt;" (for example <code>&lt;1.13.0</code>) to install the latest version satisfying the constraint. A value of <code>latest</code> will install the latest version of Terraform CLI. Defaults to <code>latest</code>.</p> | `false` | `latest` |
| `tf-terraform-wrapper` | <p>Whether or not to install a wrapper to wrap subsequent calls of the <code>terraform</code> binary and expose its STDOUT, STDERR, and exit code as outputs named <code>stdout</code>, <code>stderr</code>, and <code>exitcode</code> respectively. Defaults to <code>true</code>.</p> | `false` | `true` |


## Outputs

| name | description |
| --- | --- |
| `openshift-server-api` | <p>The server API URL of the deployed ROSA cluster</p> |
| `openshift-cluster-id` | <p>The ID of the deployed ROSA cluster</p> |
| `terraform-state-url` | <p>URL of the Terraform state file in the S3 bucket</p> |


## Runs

This action is a `composite` action.

## Usage

```yaml
- uses: camunda/camunda-tf-rosa/.github/actions/rosa-create-cluster@main
  with:
    rh-token:
    # Red Hat Hybrid Cloud Console Token
    #
    # Required: true
    # Default: ""

    cluster-name:
    # Name of the ROSA cluster to deploy
    #
    # Required: true
    # Default: ""

    admin-password:
    # Admin password for the ROSA cluster
    #
    # Required: true
    # Default: ""

    admin-username:
    # Admin username for the ROSA cluster
    #
    # Required: true
    # Default: kube-admin

    aws-region:
    # AWS region where the ROSA cluster will be deployed
    #
    # Required: true
    # Default: ""

    rosa-cli-version:
    # Version of the ROSA CLI to use
    #
    # Required: true
    # Default: latest

    awscli-version:
    # Version of the aws cli to use
    #
    # Required: true
    # Default: 2.15.52

    openshift-version:
    # Version of the OpenShift to install
    #
    # Required: true
    # Default: 4.16.10

    replicas:
    # Number of replicas for the ROSA cluster
    #
    # Required: true
    # Default: 2

    s3-backend-bucket:
    # Name of the S3 bucket to store Terraform state
    #
    # Required: true
    # Default: ""

    s3-bucket-region:
    # Region of the bucket containing the resources states, if not set, will fallback on aws-region
    #
    # Required: false
    # Default: ""

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

    login:
    # Authenticate the current kube context on the created cluster
    #
    # Required: true
    # Default: true

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
```
