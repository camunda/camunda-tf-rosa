locals {
  # For demenstration purposes, we will use owner and acceptor as separation. Naming choice will become clearer when seeing the peering setup
  cluster_name = "cl-oc"
  owner = {
    region                = "eu-central-1"
    vpc_cidr_block        = "10.65.0.0/16" # vpc for the cluster and pod range
    vpc_id                = "vpc-09a1612536ad29394"
    region_full_name      = "frankfurt"
    security_group_id     = "sg-09cda37a849a5b2ee"
    public_route_table_id = "rtb-053610e929036af2d"
    private_route_table_ids = toset([
      "rtb-0b1072f0047e11765",
      "rtb-0897438ad799e34ee"
    ])
  }
  accepter = {
    region                = "eu-west-2"
    vpc_cidr_block        = "10.64.0.0/16" # vpc for the cluster and pod range
    vpc_id                = "vpc-0f3b5372380f3b53e"
    region_full_name      = "london"
    security_group_id     = "sg-0aab15e804953617b"
    public_route_table_id = "rtb-0b6ad63dfd1159339"
    private_route_table_ids = toset([
      "rtb-09c4b68b270432944",
      "rtb-021a1f60580d83fb6"
    ])
  }
}


################################
# Peering Connection          #
################################
# This is the peering connection between the two VPCs
# You always have a requester and an accepter. The requester is the one who initiates the connection.
# That's why were using the owner and accepter naming convention.
# Auto_accept is only required in the accepter. Otherwise you have to manually accept the connection.
# Auto_accept only works in the "owner" if the VPCs are in the same region

resource "aws_vpc_peering_connection" "owner" {
  vpc_id      = local.owner.vpc_id
  peer_vpc_id = local.accepter.vpc_id
  peer_region = local.accepter.region
  auto_accept = false

  tags = {
    Name = "${local.cluster_name}-${local.owner.region_full_name}-to-${local.accepter.region_full_name}"
  }
}

resource "aws_vpc_peering_connection_accepter" "accepter" {
  provider = aws.accepter

  vpc_peering_connection_id = aws_vpc_peering_connection.owner.id
  auto_accept               = true

  tags = {
    Name = "${local.cluster_name}-${local.accepter.region_full_name}-to-${local.owner.region_full_name}"
  }
}


################################
# Route Table Updates          #
################################
# These are required to let the VPC know where to route the traffic to
# In this case non local cidr range --> VPC Peering connection.

# import {
#   to = aws_route.owner
#   id = "${local.owner.public_route_table_id}_${local.accepter.vpc_cidr_block}"
# }

resource "aws_route" "owner" {
  route_table_id            = local.owner.public_route_table_id
  destination_cidr_block    = local.accepter.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.owner.id
}

resource "aws_route" "owner_private" {
  for_each       = local.owner.private_route_table_ids
  route_table_id = each.value

  destination_cidr_block    = local.accepter.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.owner.id
}

resource "aws_route" "accepter" {
  provider = aws.accepter

  route_table_id            = local.accepter.public_route_table_id
  destination_cidr_block    = local.owner.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.owner.id
}

resource "aws_route" "accepter_private" {
  provider = aws.accepter

  for_each       = local.accepter.private_route_table_ids
  route_table_id = each.value

  destination_cidr_block    = local.owner.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.owner.id
}

################################
# Security Groups Updates      #
################################
# These changes are required to actually allow inbound traffic from the other VPC.

resource "aws_vpc_security_group_ingress_rule" "owner_eks_primary" {
  security_group_id = local.owner.security_group_id

  cidr_ipv4   = local.accepter.vpc_cidr_block
  from_port   = -1
  ip_protocol = -1
  to_port     = -1
}

resource "aws_vpc_security_group_ingress_rule" "accepter_eks_primary" {
  provider = aws.accepter

  security_group_id = local.accepter.security_group_id

  cidr_ipv4   = local.owner.vpc_cidr_block
  from_port   = -1
  ip_protocol = -1
  to_port     = -1
}
