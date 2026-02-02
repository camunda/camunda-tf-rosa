# rosa-hcp

<!-- BEGIN_TF_DOCS -->
## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_htpasswd_idp"></a> [htpasswd\_idp](#module\_htpasswd\_idp) | terraform-redhat/rosa-hcp/rhcs//modules/idp | 1.7.1 |
| <a name="module_rosa_hcp"></a> [rosa\_hcp](#module\_rosa\_hcp) | terraform-redhat/rosa-hcp/rhcs | 1.7.1 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-redhat/rosa-hcp/rhcs//modules/vpc | 1.7.1 |
## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eips.current_usage](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eips) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_servicequotas_service_quota.elastic_ip_quota](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/servicequotas_service_quota) | data source |
| [aws_vpcs.current_vpcs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs) | data source |
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | A list of availability zone names in the region. By default, this is set to `null` and is not used; instead, `availability_zones_count` manages the number of availability zones. This value should not be updated directly. To make changes, please create a new resource. | `list(string)` | `null` | no |
| <a name="input_availability_zones_count"></a> [availability\_zones\_count](#input\_availability\_zones\_count) | The count of availability (minimum 2) zones to utilize within the specified AWS Region, where pairs of public and private subnets will be generated. Valid only when availability\_zones variable is not provided. This value should not be updated, please create a new resource instead. | `number` | `2` | no |
| <a name="input_aws_availability_zones"></a> [aws\_availability\_zones](#input\_aws\_availability\_zones) | The AWS availability zones where instances of the default worker machine pool are deployed. Leave empty for the installer to pick availability zones from the VPC `availability_zones` or `availability_zones_count` | `list(string)` | `[]` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The name of the ROSA cluster to create | `string` | `"my-ocp-cluster"` | no |
| <a name="input_compute_node_instance_type"></a> [compute\_node\_instance\_type](#input\_compute\_node\_instance\_type) | The EC2 instance type to use for compute nodes | `string` | `"m7i.xlarge"` | no |
| <a name="input_host_prefix"></a> [host\_prefix](#input\_host\_prefix) | The subnet mask to assign to each compute node in the cluster | `string` | `"23"` | no |
| <a name="input_htpasswd_password"></a> [htpasswd\_password](#input\_htpasswd\_password) | htpasswd password | `string` | n/a | yes |
| <a name="input_htpasswd_username"></a> [htpasswd\_username](#input\_htpasswd\_username) | htpasswd username | `string` | `"kubeadmin"` | no |
| <a name="input_machine_cidr_block"></a> [machine\_cidr\_block](#input\_machine\_cidr\_block) | value of the CIDR block to use for the machine | `string` | `"10.0.0.0/18"` | no |
| <a name="input_openshift_version"></a> [openshift\_version](#input\_openshift\_version) | The version of ROSA to be deployed | `string` | `"4.18.5"` | no |
| <a name="input_pod_cidr_block"></a> [pod\_cidr\_block](#input\_pod\_cidr\_block) | value of the CIDR block to use for the pods | `string` | `"10.0.64.0/18"` | no |
| <a name="input_private"></a> [private](#input\_private) | Restrict master API endpoint and application routes to direct, private connectivity. | `bool` | `false` | no |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | The number of computer nodes to create. Must be a minimum of 2 for a single-AZ cluster, 3 for multi-AZ. | `string` | `"2"` | no |
| <a name="input_service_cidr_block"></a> [service\_cidr\_block](#input\_service\_cidr\_block) | value of the CIDR block to use for the services | `string` | `"10.0.128.0/18"` | no |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | value of the CIDR block to use for the VPC | `string` | `"10.0.0.0/16"` | no |
## Outputs

| Name | Description |
|------|-------------|
| <a name="output_all_subnets"></a> [all\_subnets](#output\_all\_subnets) | A comma-separated list of all subnet IDs (both public and private) in the VPC. This list can be used with the '--subnet-ids' parameter in ROSA commands for configuring cluster networking. |
| <a name="output_aws_caller_identity_account_id"></a> [aws\_caller\_identity\_account\_id](#output\_aws\_caller\_identity\_account\_id) | The AWS account ID of the caller. This is the account under which the Terraform code is being executed. |
| <a name="output_cluster_console_url"></a> [cluster\_console\_url](#output\_cluster\_console\_url) | The URL endpoint for accessing the OpenShift web console. This endpoint provides a web-based user interface for managing the OpenShift cluster. |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | The unique identifier of the OpenShift cluster created on Red Hat OpenShift Service on AWS (ROSA). This ID is used to reference the cluster in subsequent operations. |
| <a name="output_oidc_provider_id"></a> [oidc\_provider\_id](#output\_oidc\_provider\_id) | OIDC provider for the OpenShift ROSA cluster. Allows to add additional IRSA mappings. |
| <a name="output_openshift_api_url"></a> [openshift\_api\_url](#output\_openshift\_api\_url) | The URL endpoint for accessing the OpenShift API. This endpoint is used to interact with the OpenShift cluster's API server. |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | A comma-separated list of private subnet IDs in the VPC. These subnets are typically used for internal resources that do not require direct internet access. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | A comma-separated list of public subnet IDs in the VPC. These subnets are typically used for resources that require internet access. |
| <a name="output_vpc_availability_zones"></a> [vpc\_availability\_zones](#output\_vpc\_availability\_zones) | The availability zones in which the VPC is located. This provides information about the distribution of resources across different physical locations within the AWS region. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the Virtual Private Cloud (VPC) where the OpenShift cluster and related resources are deployed. |
<!-- END_TF_DOCS -->
