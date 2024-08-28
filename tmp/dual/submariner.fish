# Based on https://rcarrata.com/rosa/rosa-submariner/ + https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.2/html/manage_cluster/submariner#submariner
# https://github.com/stolostron/deploy/blob/master/README.md
# https://meatybytes.io/posts/openshift/ocp-features/multi-cluster/connectivity/

# If uninstall fails: https://access.redhat.com/solutions/6975868

# 0. Connect the two clusters peering

# Cluster 0
CLUSTER_0_INFO=$(rosa describe cluster --cluster "$CLUSTER_0" --output json)
CLUSTER_0_REGION=$(echo "$CLUSTER_0_INFO" | jq -r '.region.id')
CLUSTER_0_SUBNET_ID=$(echo "$CLUSTER_0_INFO" | jq -r '.aws.subnet_ids[0]')
CLUSTER_0_VPC_ID=$(aws ec2 describe-subnets --subnet-ids "$CLUSTER_0_SUBNET_ID" --query "Subnets[0].VpcId" --region "$CLUSTER_0_REGION" --output text)
CLUSTER_0_VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$CLUSTER_0_VPC_ID" --region "$CLUSTER_0_REGION" | jq -r '.Vpcs[0].CidrBlock')
CLUSTER_0_ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --region "$CLUSTER_0_REGION" --filters "Name=vpc-id,Values=$CLUSTER_0_VPC_ID" --query "RouteTables[*].{ID:RouteTableId,Routes:Routes}")
CLUSTER_0_PUBLIC_ROUTE_TABLE_ID=$(echo "$CLUSTER_0_ROUTE_TABLE_IDS" | jq -r '.[] | select((.Routes // []) | any(.GatewayId | (if . == null then false else startswith("igw-") end))) | .ID' | sort -u)
CLUSTER_0_PRIVATE_ROUTE_TABLE_IDS=$(echo "$CLUSTER_0_ROUTE_TABLE_IDS" | jq -r '.[] | .ID' | grep -vxFf <(echo "$CLUSTER_0_ROUTE_TABLE_IDS" | jq -r '.[] | select((.Routes // []) | any(.GatewayId | (if . == null then false else startswith("igw-") end))) | .ID') | sort -u)
CLUSTER_0_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$CLUSTER_0_VPC_ID" --region "$CLUSTER_0_REGION" | jq -r '.SecurityGroups[0].GroupId')
CLUSTER_0_PRIVATE_ROUTE_TABLE_IDS_JSON=$(echo "$CLUSTER_0_PRIVATE_ROUTE_TABLE_IDS" | jq -R -s 'split("\n") | map(select(length > 0))')

# Cluster 1
CLUSTER_1_INFO=$(rosa describe cluster --cluster "$CLUSTER_1" --output json)
CLUSTER_1_REGION=$(echo "$CLUSTER_1_INFO" | jq -r '.region.id')
CLUSTER_1_SUBNET_ID=$(echo "$CLUSTER_1_INFO" | jq -r '.aws.subnet_ids[0]')
CLUSTER_1_VPC_ID=$(aws ec2 describe-subnets --subnet-ids "$CLUSTER_1_SUBNET_ID" --query "Subnets[0].VpcId" --region "$CLUSTER_1_REGION" --output text)
CLUSTER_1_VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$CLUSTER_1_VPC_ID" --region "$CLUSTER_1_REGION" | jq -r '.Vpcs[0].CidrBlock')
CLUSTER_1_ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --region "$CLUSTER_1_REGION" --filters "Name=vpc-id,Values=$CLUSTER_1_VPC_ID" --query "RouteTables[*].{ID:RouteTableId,Routes:Routes}")
CLUSTER_1_PUBLIC_ROUTE_TABLE_ID=$(echo "$CLUSTER_1_ROUTE_TABLE_IDS" | jq -r '.[] | select((.Routes // []) | any(.GatewayId | (if . == null then false else startswith("igw-") end))) | .ID' | sort -u)
CLUSTER_1_PRIVATE_ROUTE_TABLE_IDS=$(echo "$CLUSTER_1_ROUTE_TABLE_IDS" | jq -r '.[] | .ID' | grep -vxFf <(echo "$CLUSTER_1_ROUTE_TABLE_IDS" | jq -r '.[] | select((.Routes // []) | any(.GatewayId | (if . == null then false else startswith("igw-") end))) | .ID') | sort -u)
CLUSTER_1_SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$CLUSTER_1_VPC_ID" --region "$CLUSTER_1_REGION" | jq -r '.SecurityGroups[0].GroupId')
CLUSTER_1_PRIVATE_ROUTE_TABLE_IDS_JSON=$(echo "$CLUSTER_1_PRIVATE_ROUTE_TABLE_IDS" | jq -R -s 'split("\n") | map(select(length > 0))')

terraform init  -backend-config="bucket=camunda-tf-rosa" -backend-config="key=tfstate-$CLUSTER_0-$CLUSTER_1/peering.tfstate" -backend-config="region=eu-west-2"

OWNER_JSON=$(jq -n \
  --arg region "$CLUSTER_0_REGION" \
  --arg vpc_cidr_block "$CLUSTER_0_VPC_CIDR" \
  --arg vpc_id "$CLUSTER_0_VPC_ID" \
  --arg security_group_id "$CLUSTER_0_SECURITY_GROUP_ID" \
  --arg public_route_table_id "$CLUSTER_0_PUBLIC_ROUTE_TABLE_ID" \
  --argjson private_route_table_ids "$CLUSTER_0_PRIVATE_ROUTE_TABLE_IDS_JSON" \
  '{
    region: $region,
    vpc_cidr_block: $vpc_cidr_block,
    vpc_id: $vpc_id,
    security_group_id: $security_group_id,
    public_route_table_id: $public_route_table_id,
    private_route_table_ids: $private_route_table_ids
  }')

ACCEPTER_JSON=$(jq -n \
  --arg region "$CLUSTER_1_REGION" \
  --arg vpc_cidr_block "$CLUSTER_1_VPC_CIDR" \
  --arg vpc_id "$CLUSTER_1_VPC_ID" \
  --arg security_group_id "$CLUSTER_1_SECURITY_GROUP_ID" \
  --arg public_route_table_id "$CLUSTER_1_PUBLIC_ROUTE_TABLE_ID" \
  --argjson private_route_table_ids "$CLUSTER_1_PRIVATE_ROUTE_TABLE_IDS_JSON" \
  '{
    region: $region,
    vpc_cidr_block: $vpc_cidr_block,
    vpc_id: $vpc_id,
    security_group_id: $security_group_id,
    public_route_table_id: $public_route_table_id,
    private_route_table_ids: $private_route_table_ids
  }')

# Print JSON objects
echo "Terraform Variables for Owner ($CLUSTER_0):"
echo "$OWNER_JSON"

echo "Terraform Variables for Accepter ($CLUSTER_1):"
echo "$ACCEPTER_JSON"

terraform plan -out peering.plan \
  -var "owner=$(echo "$OWNER_JSON" | jq -c .)" \
  -var "accepter=$(echo "$ACCEPTER_JSON" | jq -c .)"


terraform apply "peering.plan"


# terraform destroy \
#   -var "owner=$(echo "$OWNER_JSON" | jq -c .)" \
#   -var "accepter=$(echo "$ACCEPTER_JSON" | jq -c .)"


# I. Deploy RHACM Cluster Hub (TODO: this chapter is bugged and doing it via the UI works)

kubectl --context $CLUSTER_0 apply -f submariner/acm-ns.yml
kubectl --context $CLUSTER_0 apply -f submariner/operatorgroup.yml
kubectl --context $CLUSTER_0 apply -f submariner/acm-sub.yml

# Verify the installation
# wait until it's "Succeeded"
kubectl --context $CLUSTER_0 --namespace open-cluster-management get csv --watch

# Install MultiClusterHub
kubectl --context $CLUSTER_0 apply -f submariner/multi-cluster-hub.yml
# wait until it's "Running", can take up to 10 minutes
kubectl --context $CLUSTER_0 get mch -n open-cluster-management multiclusterhub --watch

## II. Prepare Cluster Hub for Submariner

# Create submariner machine pools (this is required by https://github.com/submariner-io/submariner/issues/1896)
# (TODO: this could be integrated directly in the tf module

rosa create machinepool --cluster $CLUSTER_0 --name=sm-gw-mp --replicas=1 --labels='submariner.io/gateway=true' # todo: ideally, deploy accross regions
rosa list machinepools -c $CLUSTER_0


rosa create machinepool --cluster $CLUSTER_1 --name=sm-gw-mp --replicas=1 --labels='submariner.io/gateway=true'
rosa list machinepools -c $CLUSTER_1

# wait for nodes to be ready
kubectl --context $CLUSTER_0 get nodes --show-labels --watch | grep submariner
kubectl --context $CLUSTER_1 get nodes --show-labels --watch | grep submariner

# Create the ManagedClusterSet in the Cluster0
kubectl --context $CLUSTER_0 get mch -A
kubectl --context $CLUSTER_0  apply -f submariner/managed-cluster-set.yml

# Import Cluster 0
set -x SUB0_TOKEN (oc --context "$CLUSTER_0" whoami -t)
echo $SUB0_TOKEN

CLUSTER_NAME="$CLUSTER_0" envsubst < submariner/managed-cluster.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_0" CLUSTER_TOKEN="$SUB0_TOKEN" CLUSTER_API="$CLUSTER_0_API_URL" envsubst < submariner/auto-import-cluster-secret.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_0" envsubst < submariner/klusterlet-config.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -

# List Managed Cluster sets
kubectl --context "$CLUSTER_0" get managedclusters "$CLUSTER_0"


# Import Cluster 1
set -x SUB1_TOKEN (oc --context "$CLUSTER_1" whoami -t)
echo $SUB1_TOKEN

CLUSTER_NAME="$CLUSTER_1" envsubst < submariner/managed-cluster.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_1" CLUSTER_TOKEN="$SUB1_TOKEN" CLUSTER_API="$CLUSTER_1_API_URL" envsubst < submariner/auto-import-cluster-secret.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_1" envsubst < submariner/klusterlet-config.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -


kubectl --context "$CLUSTER_0" get managedclusters

# edit local cluster
# cluster.open-cluster-management.io/clusterset=rosa-clusters

# NAME            HUB ACCEPTED   MANAGED CLUSTER URLS                                 JOINED   AVAILABLE   AGE
# cl-oc-1b        true           https://api.cl-oc-1b.f70c.p3.openshiftapps.com:443   True     True        6m13s
# cl-oc-2         true           https://api.cl-oc-2.5egh.p3.openshiftapps.com:443    True     True        50s
# local-cluster   true           https://api.cl-oc-1b.f70c.p3.openshiftapps.com:443   True     True        36m


# IV. Deploy Submariner addon

# TODO: use manifests for this part
# Deploy Submariner Addon in Managed ROSA clusters from the RHACM UI
#     Inside of the ClusterSets tab, go to the rosa-aro-clusters generated.
#     Go to Submariner add-ons and Click in “Install Submariner Add-Ons”
#     Configure the Submariner addons adding both ROSA clusters generated:

# Check readiness

# Install subctl
# https://submariner.io/operations/deployment/subctl/
curl -Ls https://get.submariner.io | bash
export PATH=$PATH:~/.local/bin
echo export PATH=\$PATH:~/.local/bin >> ~/.profile

# verify the installation

subctl show all

# ╰─λ subctl show all                                                                                                                                                                                                                              0 (9.582s) < 17:04:47
# Cluster "api-cl-oc-2-uloo-p3-openshiftapps-com:443"
#  ✓ Detecting broker(s)
#  ✓ No brokers found

#  ✓ Showing Connections
# GATEWAY          CLUSTER         REMOTE IP        NAT   CABLE DRIVER   SUBNETS                       STATUS      RTT avg.
# ip-10-0-41-113   local-cluster   18.158.240.189   yes   libreswan      10.0.128.0/18, 10.0.64.0/18   connected   26.707065ms

#  ✓ Showing Endpoints
# CLUSTER         ENDPOINT IP   PUBLIC IP        CABLE DRIVER   TYPE
# cl-oc-2         10.1.42.49    54.220.24.218    libreswan      local
# cl-oc-2         10.1.44.96    54.220.24.218    libreswan      local
# local-cluster   10.0.41.113   18.158.240.189   libreswan      remote

#  ✓ Showing Gateways
# NODE            HA STATUS   SUMMARY
# ip-10-1-42-49   passive     There are no connections
# ip-10-1-44-96   active      All connections (1) are established

#  ✓ Showing Network details
#     Discovered network details via Submariner:
#         Network plugin:  OVNKubernetes
#         Service CIDRs:   [10.1.128.0/18]
#         Cluster CIDRs:   [10.1.64.0/18]

#  ✓ Showing versions
# COMPONENT                       REPOSITORY                  CONFIGURED                                                         RUNNING   ARCH
# submariner-gateway              registry.redhat.io/rhacm2   c66ccbebd1e1594d87a1e6920ea56b5fe831bd5b5745636c3118db6825b04c8a   v0.18.0   amd64
# submariner-routeagent           registry.redhat.io/rhacm2   ca7a835c1f1c0b717c2cc23b30d82877f540a6b502952c46ac5452b25d08f6ee   v0.18.0   amd64
# submariner-metrics-proxy        registry.redhat.io/rhacm2   47a0bb401f93e523df2d12d72b20c73237cad67a22eb6c8b65e07e245aef7800   v0.18.0   amd64
# submariner-operator             registry.redhat.io/rhacm2   81584ffcbd0efee8d1fa80e0f0c34062cc78340087dfb24ded6300801ea7153f   v0.18.0   amd64
# submariner-lighthouse-agent     registry.redhat.io/rhacm2   7884cd1b32aecddb55e74d9d1ddc6f3e8398d76a710932c5e6fe8652956367ff   v0.18.0   amd64
# submariner-lighthouse-coredns   registry.redhat.io/rhacm2   aa49dcea83fc3057c4da55ee72b599f8dc0e0127d033dc7bd223b6d617ebf30c   v0.18.0   amd64


# Cluster "api-cl-oc-1b-ckhb-p3-openshiftapps-com:443"
#  ✓ Detecting broker(s)
# NAMESPACE              NAME                COMPONENTS   GLOBALNET   GLOBALNET CIDR   DEFAULT GLOBALNET SIZE   DEFAULT DOMAINS
# rosa-clusters-broker   submariner-broker                no                           0

#  ✓ Showing Connections
# GATEWAY         CLUSTER   REMOTE IP       NAT   CABLE DRIVER   SUBNETS                       STATUS      RTT avg.
# ip-10-1-44-96   cl-oc-2   54.220.24.218   yes   libreswan      10.1.128.0/18, 10.1.64.0/18   connected   26.779562ms

#  ✓ Showing Endpoints
# CLUSTER         ENDPOINT IP   PUBLIC IP        CABLE DRIVER   TYPE
# local-cluster   10.0.36.169   3.77.135.47      libreswan      local
# local-cluster   10.0.41.113   18.158.240.189   libreswan      local
# cl-oc-2         10.1.44.96    54.220.24.218    libreswan      remote

#  ✓ Showing Gateways
# NODE             HA STATUS   SUMMARY
# ip-10-0-36-169   passive     There are no connections
# ip-10-0-41-113   active      All connections (1) are established

#  ✓ Showing Network details
#     Discovered network details via Submariner:
#         Network plugin:  OVNKubernetes
#         Service CIDRs:   [10.0.128.0/18]
#         Cluster CIDRs:   [10.0.64.0/18]

#  ✓ Showing versions
# COMPONENT                       REPOSITORY                  CONFIGURED                                                         RUNNING   ARCH
# submariner-gateway              registry.redhat.io/rhacm2   c66ccbebd1e1594d87a1e6920ea56b5fe831bd5b5745636c3118db6825b04c8a   v0.18.0   amd64
# submariner-routeagent           registry.redhat.io/rhacm2   ca7a835c1f1c0b717c2cc23b30d82877f540a6b502952c46ac5452b25d08f6ee   v0.18.0   amd64
# submariner-metrics-proxy        registry.redhat.io/rhacm2   47a0bb401f93e523df2d12d72b20c73237cad67a22eb6c8b65e07e245aef7800   v0.18.0   amd64
# submariner-operator             registry.redhat.io/rhacm2   81584ffcbd0efee8d1fa80e0f0c34062cc78340087dfb24ded6300801ea7153f   v0.18.0   amd64
# submariner-lighthouse-agent     registry.redhat.io/rhacm2   7884cd1b32aecddb55e74d9d1ddc6f3e8398d76a710932c5e6fe8652956367ff   v0.18.0   amd64
# submariner-lighthouse-coredns   registry.redhat.io/rhacm2   aa49dcea83fc3057c4da55ee72b599f8dc0e0127d033dc7bd223b6d617ebf30c   v0.18.0   amd64

# If you have issues, you could use
# subctl diagnose all

# IV. Deploy the test app

./test_dns_chaining.sh

# the ns must be present in both clusters
kubectl --context "$CLUSTER_0" create namespace "$CAMUNDA_NAMESPACE_1"
kubectl --context "$CLUSTER_1" create namespace "$CAMUNDA_NAMESPACE_0"

kubectl --context "$CLUSTER_0" apply -f nginx-submariner.yaml -n "$CAMUNDA_NAMESPACE_0"
kubectl --context "$CLUSTER_1" apply -f nginx-submariner.yaml -n "$CAMUNDA_NAMESPACE_1"

# then check the serviceexport for each
kubectl --context "$CLUSTER_0" -n "$CAMUNDA_NAMESPACE_0" describe serviceexport
kubectl --context "$CLUSTER_1" -n "$CAMUNDA_NAMESPACE_1" describe serviceexport

# Message:               Service was successfully exported to the broker
# Reason:
# Status:                True
# Type:                  Ready
# Events:                    <none>


# Check if the serviceexport has been imported on the other side

kubectl --context "$CLUSTER_0" -n "$CAMUNDA_NAMESPACE_0" describe serviceimport
kubectl --context "$CLUSTER_1" -n "$CAMUNDA_NAMESPACE_1" describe serviceimport


# Notice that for Cluster 0, the name is "local-cluster"

# Deploy a debug pod to test inter-connection
kubectl --context $CLUSTER_0  apply -f debug.yml
kubectl --context $CLUSTER_1  apply -f debug.yml

# You will see the creation of the ServiceImport in the pod  submariner-lighthouse-agent-

# From any cluster, you should be able to query the nginx pod in the other cluster using the debug pod shell:
# curl sample-nginx.cl-oc-2.sample-nginx-peer.camunda-cl-oc-2.svc.clusterset.local:8080
# curl sample-nginx.local-cluster.sample-nginx-peer.camunda-cl-oc-1b.svc.clusterset.local:8080

# the format for headless services is:
# <pod>.<cluster-name>.<service-name>.<namespace>.svc.clusterset.local

# https://submariner.io/operations/usage/
# Once the Service is exported successfully, it can be discovered as
# nginx-ss.nginx-test.svc.clusterset.local across the cluster set.
# In addition, the individual Pods can be accessed as web-0.cluster3.nginx-ss.nginx-test.svc.clusterset.local and web-1.cluster3.nginx-ss.nginx-test.svc.clusterset.local.

# IV. Deploy C8
