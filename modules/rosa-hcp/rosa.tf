data "aws_region" "current" {}

locals {
  account_role_prefix  = "${var.cluster_name}-account"
  operator_role_prefix = "${var.cluster_name}-operator"

  tags = {
    "owner" = data.aws_caller_identity.current.arn
  }

  cluster_region = (
    # Check if `availability_zones` is defined and not empty
    length(var.availability_zones) > 0 && var.availability_zones != null
    ? substr(var.availability_zones[0], 0, length(var.availability_zones[0]) - 1) # Extract region from the first AZ
    : (
      # Check if `aws_availability_zones` is defined and not empty
      length(var.aws_availability_zones) > 0 && var.aws_availability_zones != null
      ? substr(var.aws_availability_zones[0], 0, length(var.aws_availability_zones[0]) - 1) # Extract region from the first AZ
      : data.aws_region.current.name                                                        # Fallback to the default region
    )
  )

  availability_zones_count_computed = (
    var.availability_zones != null && length(var.availability_zones) > 0
    ? length(var.availability_zones) # If `availability_zones` is defined, use its length
    : var.availability_zones_count   # Otherwise, use `availability_zones_count`
  )
}

data "external" "elastic_ip_quota" {
  program = ["bash", "./get_elastic_ips_quota.sh", local.cluster_region]
}


data "external" "elastic_ips_count" {
  program = ["bash", "./get_elastic_ips_count.sh", local.cluster_region]
}


check "elastic_ip_quota_check" {
  assert {
    condition     = tonumber(data.external.elastic_ip_quota.result.quota) >= local.availability_zones_count_computed
    error_message = "The Elastic IP quota is insufficient to cover all local availability zones (need: ${local.availability_zones_count_computed}, have: ${tonumber(data.external.elastic_ip_quota.result.quota)})."
  }

  assert {
    condition     = (tonumber(data.external.elastic_ip_quota.result.quota) - tonumber(data.external.elastic_ips_count.result.elastic_ips_count)) >= local.availability_zones_count_computed
    error_message = "Not enough available Elastic IPs to cover all local availability zones (need: ${local.availability_zones_count_computed}, have: ${(tonumber(data.external.elastic_ip_quota.result.quota) - tonumber(data.external.elastic_ips_count.result.elastic_ips_count))})."
  }
}


module "rosa_hcp" {
  source  = "terraform-redhat/rosa-hcp/rhcs"
  version = "1.6.5"

  openshift_version = var.openshift_version
  cluster_name      = var.cluster_name

  compute_machine_type = var.compute_node_instance_type
  tags                 = local.tags

  machine_cidr = var.machine_cidr_block
  service_cidr = var.service_cidr_block
  pod_cidr     = var.pod_cidr_block
  properties   = { rosa_creator_arn = data.aws_caller_identity.current.arn }


  replicas               = var.replicas
  aws_availability_zones = length(var.aws_availability_zones) > 0 ? var.aws_availability_zones : module.vpc.availability_zones

  aws_subnet_ids = concat(
    module.vpc.public_subnets, module.vpc.private_subnets,
  )

  host_prefix = var.host_prefix

  // STS configuration
  create_account_roles  = true
  account_role_prefix   = local.account_role_prefix
  create_oidc           = true
  create_operator_roles = true
  operator_role_prefix  = local.operator_role_prefix

  wait_for_create_complete            = true
  wait_for_std_compute_nodes_complete = true

  depends_on = [
    module.vpc,
  ]
}

module "htpasswd_idp" {
  source  = "terraform-redhat/rosa-hcp/rhcs//modules/idp"
  version = "1.6.5"

  cluster_id         = module.rosa_hcp.cluster_id
  name               = "htpasswd-idp"
  idp_type           = "htpasswd"
  htpasswd_idp_users = [{ username = var.htpasswd_username, password = var.htpasswd_password }]
}

module "vpc" {
  source  = "terraform-redhat/rosa-hcp/rhcs//modules/vpc"
  version = "1.6.5"

  name_prefix = var.cluster_name

  availability_zones_count = var.availability_zones != null ? null : var.availability_zones_count
  availability_zones       = var.availability_zones

  vpc_cidr = var.vpc_cidr_block
}
