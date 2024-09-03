# s3-es

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Modules

No modules.
## Resources

| Name | Type |
|------|------|
| [aws_iam_access_key.service_account_access_key](https://registry.terraform.io/providers/hashicorp/aws/5.51.1/docs/resources/iam_access_key) | resource |
| [aws_iam_policy.s3_access_policy](https://registry.terraform.io/providers/hashicorp/aws/5.51.1/docs/resources/iam_policy) | resource |
| [aws_iam_user.service_account](https://registry.terraform.io/providers/hashicorp/aws/5.51.1/docs/resources/iam_user) | resource |
| [aws_iam_user_policy_attachment.s3_access_attachment](https://registry.terraform.io/providers/hashicorp/aws/5.51.1/docs/resources/iam_user_policy_attachment) | resource |
| [aws_s3_bucket.elastic_backup](https://registry.terraform.io/providers/hashicorp/aws/5.51.1/docs/resources/s3_bucket) | resource |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster to prefix resources | `string` | n/a | yes |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_s3_aws_access_key"></a> [s3\_aws\_access\_key](#output\_s3\_aws\_access\_key) | n/a |
| <a name="output_s3_aws_secret_access_key"></a> [s3\_aws\_secret\_access\_key](#output\_s3\_aws\_secret\_access\_key) | n/a |
| <a name="output_s3_bucket_name"></a> [s3\_bucket\_name](#output\_s3\_bucket\_name) | n/a |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
