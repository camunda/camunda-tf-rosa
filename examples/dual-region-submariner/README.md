# Creating Two OpenShift Clusters Across Two Regions and deploy C8

**⚠️ Note:** This guide currently has no production support and is intended as a proof of concept for testing purposes only.

This guide provides step-by-step instructions for creating two OpenShift clusters in different AWS regions and configuring Camunda 8 on these clusters.

It utilizes [OpenShift Advanced Cluster Management (ACM)](https://www.redhat.com/en/technologies/management/advanced-cluster-management) and [Submariner](https://submariner.io/).

The same approach can be applied to other OpenShift flavors that support Submariner (such as Azure, GCP, etc.), but it has only been tested on ROSA HCP.

![Submariner Multi-Cluster Connectivity](https://meatybytes.io/posts/openshift/ocp-features/multi-cluster/connectivity/submariner_hu3f3d03703861280d02732de1b37dcf8b_72389_1320x0_resize_box_3.png)

## Prerequisites

Before you start, make sure you have the following tools installed:

- **AWS CLI**: To interact with AWS services.
- **Terraform**: For provisioning and managing the infrastructure.
- **ROSA CLI**: Red Hat OpenShift Service on AWS CLI, used for managing OpenShift clusters.
- **kubectl**: To manage Kubernetes clusters.
- **helm**: For managing Kubernetes applications.
- **jq**: A lightweight and flexible command-line JSON processor.

You can use the command `just install-tooling` to install most of these tools, except for ROSA CLI. To install ROSA CLI, follow the instructions provided in the [ROSA CLI documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_service_on_aws/4/html-single/rosa_cli/index#rosa-get-started-cli).

## Step-by-Step Instructions

### 1. Define Environment Variables

Set up the environment variables for both regions and clusters:

```bash
# Define the regions
export REGION_0=eu-central-1
export REGION_1=eu-west-1

# Define the cluster names
export CLUSTER_0=cl-oc-1
export CLUSTER_1=cl-oc-2

# Important Note:
# Ensure that the CIDR blocks for each cluster do not overlap.
# Each cluster must have distinct IP address ranges to avoid conflicts.

# Define the CIDR blocks for cluster 0
export CLUSTER_0_VPC_CIDR="10.0.0.0/16"
export CLUSTER_0_MACHINE_CIDR="10.0.0.0/18"
export CLUSTER_0_POD_CIDR="10.0.64.0/18"
export CLUSTER_0_SERVICE_CIDR="10.0.128.0/18"

# Define the CIDR blocks for cluster 1
export CLUSTER_1_VPC_CIDR="10.1.0.0/16"
export CLUSTER_1_MACHINE_CIDR="10.1.0.0/18"
export CLUSTER_1_POD_CIDR="10.1.64.0/18"
export CLUSTER_1_SERVICE_CIDR="10.1.128.0/18"

# Define the namespaces for Camunda
export CAMUNDA_NAMESPACE_0="camunda-$CLUSTER_0"
export CAMUNDA_NAMESPACE_0_FAILOVER="$CAMUNDA_NAMESPACE_0-failover"
export CAMUNDA_NAMESPACE_1="camunda-$CLUSTER_1"
export CAMUNDA_NAMESPACE_1_FAILOVER="$CAMUNDA_NAMESPACE_1-failover"

# Define the Helm release name and chart version
export HELM_RELEASE_NAME=camunda
export HELM_CHART_VERSION=10.1.1

# Define where you want to store your state
export TF_STATE_BUCKET_NAME=camunda-tf-rosa
export TF_STATE_BUCKET_REGION=eu-west-2
```

### 2. Set Up Cluster 0

Navigate to the directory for cluster 0 setup and initialize Terraform:

```bash
cd rosa-hcp-eu-central-1
export AWS_REGION="$REGION_0"
export RH_TOKEN="yourToken" # you can get it from https://console.redhat.com/openshift/token
export KUBEADMIN_PASSWORD="yourPassword" # define a password of your choice

rosa login --token="$RH_TOKEN"

terraform init -backend-config="bucket=$TF_STATE_BUCKET_NAME" -backend-config="key=tfstate-$CLUSTER_0/$CLUSTER_0.tfstate" -backend-config="region=$TF_STATE_BUCKET_REGION"

terraform plan -out rosa.plan -var "cluster_name=$CLUSTER_0" -var "htpasswd_password=$KUBEADMIN_PASSWORD" -var "offline_access_token=$RH_TOKEN" -var "replicas=4" -var "vpc_cidr_block=$CLUSTER_0_VPC_CIDR"  -var "machine_cidr_block=$CLUSTER_0_MACHINE_CIDR"  -var "service_cidr_block=$CLUSTER_0_SERVICE_CIDR"  -var "pod_cidr_block=$CLUSTER_0_POD_CIDR"

terraform apply "rosa.plan"
```

### 3. Set Up Cluster 1

Navigate to the directory for cluster 1 setup and initialize Terraform:

```bash
cd rosa-hcp-eu-west-1
export AWS_REGION="$REGION_1"
export RH_TOKEN="yourToken" # you can get it from https://console.redhat.com/openshift/token
export KUBEADMIN_PASSWORD="yourPassword" # define a password of your choice

rosa login --token="$RH_TOKEN"

terraform init -backend-config="bucket=$TF_STATE_BUCKET_NAME" -backend-config="key=tfstate-$CLUSTER_1/$CLUSTER_1.tfstate" -backend-config="region=$TF_STATE_BUCKET_REGION"

terraform plan -out rosa.plan -var "cluster_name=$CLUSTER_1" -var "htpasswd_password=$KUBEADMIN_PASSWORD" -var "offline_access_token=$RH_TOKEN" -var "replicas=4" -var "vpc_cidr_block=$CLUSTER_1_VPC_CIDR"  -var "machine_cidr_block=$CLUSTER_1_MACHINE_CIDR"  -var "service_cidr_block=$CLUSTER_1_SERVICE_CIDR"  -var "pod_cidr_block=$CLUSTER_1_POD_CIDR"

terraform apply "rosa.plan"
```

### 4. Retrieve Cluster Information

Retrieve the cluster IDs and API URLs:

```bash
export CLUSTER_0_ID=$(rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .id" -r)
export CLUSTER_0_API_URL=$(rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .api.url" -r)
export CLUSTER_1_ID=$(rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .id" -r)
export CLUSTER_1_API_URL=$(rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .api.url"  -r)

```

### 5. Log In to Clusters

Log in to both clusters. It is recommended to keep each cluster in a dedicated terminal for ease of use:
```bash
# Login to Cluster 0
rosa grant user cluster-admin --cluster="$CLUSTER_0" --user=kubeadmin
oc login -u kubeadmin "$CLUSTER_0_API_URL" -p "$KUBEADMIN_PASSWORD"
kubectl config delete-context "$CLUSTER_0"
kubectl config rename-context $(oc config current-context) "$CLUSTER_0"
kubectl config use "$CLUSTER_0"

# Login to Cluster 1
rosa grant user cluster-admin --cluster="$CLUSTER_1" --user=kubeadmin
oc login -u kubeadmin "$CLUSTER_1_API_URL" -p "$KUBEADMIN_PASSWORD"
kubectl config delete-context "$CLUSTER_1"
kubectl config rename-context $(oc config current-context) "$CLUSTER_1"
kubectl config use "$CLUSTER_1"
```

### 6. Configure Clusters Peering

This step is necessary to connect the two clusters via their dedicated VPCs. Follow the instructions below to configure VPC peering between Cluster 0 and Cluster 1:

```bash
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

terraform init  -backend-config="bucket=$TF_STATE_BUCKET_NAME" -backend-config="key=tfstate-$CLUSTER_0-$CLUSTER_1/peering.tfstate" -backend-config="region=$TF_STATE_BUCKET_REGION"

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

echo "Terraform Variables for Owner ($CLUSTER_0):"
echo "$OWNER_JSON"

echo "Terraform Variables for Accepter ($CLUSTER_1):"
echo "$ACCEPTER_JSON"

terraform plan -out peering.plan \
  -var "owner=$(echo "$OWNER_JSON" | jq -c .)" \
  -var "accepter=$(echo "$ACCEPTER_JSON" | jq -c .)"


terraform apply "peering.plan"
```
If you want to destroy it:

```bash
# terraform destroy \
#   -var "owner=$(echo "$OWNER_JSON" | jq -c .)" \
#   -var "accepter=$(echo "$ACCEPTER_JSON" | jq -c .)"
```

### 7. Install OpenShift ACM and Submariner

This part has been successfully completed using the UI, but it should also work using the manifests.

The installation process is adapted from [this guide](https://rcarrata.com/rosa/rosa-submariner/). In this setup, we use only two OpenShift clusters, with one (Cluster 0) referenced as `local-cluster`. This designation cannot be changed.

For a production installation, it is recommended to follow the official Red Hat documentation: [Installing Advanced Cluster Management](https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.1/html/install/installing).

Cluster 0 is referenced as the Controller Cluster and handles all management resources, such as ACM and Submariner.

```bash
cd dual

kubectl --context $CLUSTER_0 apply -f acm/acm-ns.yml
kubectl --context $CLUSTER_0 apply -f acm/operatorgroup.yml
kubectl --context $CLUSTER_0 apply -f acm/acm-sub.yml

# Verify the installationn, wait until it's "Succeeded"
kubectl --context $CLUSTER_0 --namespace open-cluster-management get csv --watch

# Install MultiClusterHub
kubectl --context $CLUSTER_0 apply -f acm/multi-cluster-hub.yml
# wait until it's "Running", can take up to 10 minutes
kubectl --context $CLUSTER_0 get mch -n open-cluster-management multiclusterhub --watch

# Create the ManagedClusterSet in the Cluster0
kubectl --context $CLUSTER_0 get mch -A
kubectl --context $CLUSTER_0  apply -f acm/managed-cluster-set.yml
```

Once the set of cluster has been created, we can import the clusters:
```bash
# Import CLUSTER_0
SUB0_TOKEN=$(oc --context "$CLUSTER_0" whoami -t)

# for cluster 0, the cluster name is hardcoded on purpose
CLUSTER_NAME="local-cluster" envsubst < acm/managed-cluster.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="local-cluster" CLUSTER_TOKEN="$SUB0_TOKEN" CLUSTER_API="$CLUSTER_0_API_URL" envsubst < acm/auto-import-cluster-secret.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="local-cluster" envsubst < acm/klusterlet-config.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
# List Managed Cluster sets
kubectl --context "$CLUSTER_0" get managedclusters

# Import CLUSTER_1
SUB1_TOKEN=$(oc --context "$CLUSTER_1" whoami -t)

CLUSTER_NAME="$CLUSTER_1" envsubst < submariner/managed-cluster.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_1" CLUSTER_TOKEN="$SUB1_TOKEN" CLUSTER_API="$CLUSTER_1_API_URL" envsubst < submariner/auto-import-cluster-secret.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_1" envsubst < submariner/klusterlet-config.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -

kubectl --context "$CLUSTER_0" get managedclusters
# NAME            HUB ACCEPTED   MANAGED CLUSTER URLS                                 JOINED   AVAILABLE   AGE
# cl-oc-2         true           https://api.cl-oc-2.5egh.p3.openshiftapps.com:443    True     True        50s
# local-cluster   true           https://api.cl-oc-1.f70c.p3.openshiftapps.com:443   True     True        36m
```

### 8. Install Submariner in the Clusters

#### Create the Broker Nodes

Submariner requires a dedicated broker node in each cluster. We will create one in each cluster using the rosa CLI. Alternatively, you could use the Terraform module for this setup later.

```bash
rosa create machinepool --cluster $CLUSTER_0 --name=sm-gw-mp --replicas=1 --labels='submariner.io/gateway=true' # todo: ideally, deploy accross regions
rosa list machinepools -c $CLUSTER_0


rosa create machinepool --cluster $CLUSTER_1 --name=sm-gw-mp --replicas=1 --labels='submariner.io/gateway=true'
rosa list machinepools -c $CLUSTER_1

# wait for nodes to be ready
kubectl --context $CLUSTER_0 get nodes --show-labels --watch | grep submariner
kubectl --context $CLUSTER_1 get nodes --show-labels --watch | grep submariner
```

#### Install Submariner Addon

To install Submariner, start by setting up the `subctl` CLI:

```bash
# Install subctl
curl -Ls https://get.submariner.io | bash
export PATH=$PATH:~/.local/bin
echo export PATH=\$PATH:~/.local/bin >> ~/.profile
```

The installation of Submariner can be performed through the UI, but you can also use manifests for this purpose. For a UI tutorial, visit: [Submariner Installation Guide](https://rcarrata.com/rosa/rosa-submariner/).

```bash
envsubst < submariner/submariner-addon.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -

# wait until the brokers are ready
kubectl --context "$CLUSTER_0" -n "rosa-clusters-broker" describe Broker
kubectl --context "$CLUSTER_1" -n "rosa-clusters-broker" describe Broker

# verify the communication between the clusters (you can also use the UI)
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


# Cluster "api-cl-oc-1-ckhb-p3-openshiftapps-com:443"
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
```

#### Test the Inter-Cluster Communication

To verify inter-cluster communication, deploy a simple HTTP service and a debug pod on each cluster, then test connectivity between the clusters. This process has been automated in the `test_dns_chaining.sh` script.

Run the following command to execute the test:

```bash
./test_dns_chaining.sh
```

The script will:

1. Set up the test environment.
2. Deploy the HTTP services and debug pods.
3. Describe the deployments.
4. Attempt to reach each service from the other cluster.

Upon successful completion of this script, the inter-cluster communication infrastructure will be properly configured!

### 8. Setup S3 for Elasticsearch for C8 multi-region

Set up S3 for Elasticsearch:

```bash
cd s3-es
export AWS_REGION="$REGION_0"
terraform init  -backend-config="bucket=$TF_STATE_BUCKET_NAME" -backend-config="key=tfstate-$CLUSTER_0-$CLUSTER_1-s3/bucket.tfstate" -backend-config="region=$TF_STATE_BUCKET_REGION"
terraform plan -out "s3.plan" -var "cluster_name=$CLUSTER_0-$CLUSTER_1"
terraform apply "s3.plan"

export AWS_ACCESS_KEY_ES=$(terraform output -raw s3_aws_access_key)
export AWS_SECRET_ACCESS_KEY_ES=$(terraform output -raw s3_aws_secret_access_key)

# Create the secrets in kubectl and the namespaces, notice that all the cluster needs to have the namespaces of the other, this is a requirement of submariner.
cd ..
./create_elasticsearch_secrets.sh

# Cleanup the secrets
unset AWS_ACCESS_KEY_ES
unset AWS_SECRET_ACCESS_KEY_ES
```

### 9. Prepare for Deployment

Prepare the clusters for C8 helm deployment:

```bash
export REGION_0_ZEEBE_SERVICE_NAME=$(echo "local-cluster.${HELM_RELEASE_NAME}-zeebe.${CAMUNDA_NAMESPACE_0}.svc.clusterset.local")
export REGION_1_ZEEBE_SERVICE_NAME=$(echo "${CLUSTER_1}.${HELM_RELEASE_NAME}-zeebe.${CAMUNDA_NAMESPACE_1}.svc.clusterset.local")

# Not yet used
export REGION_0_INGRESS_BASE_DOMAIN=$(kubectl --context $CLUSTER_0 get IngressController default -n openshift-ingress-operator -o jsonpath='{.spec.domain}')
export REGION_1_INGRESS_BASE_DOMAIN=$(kubectl --context $CLUSTER_1 get IngressController default -n openshift-ingress-operator -o jsonpath='{.spec.domain}')

python generate_zeebe_values_submariner.py

# Set the output values
export ZEEBE_BROKER_CLUSTER_INITIALCONTACTPOINTS="fill"
export ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION0_ARGS_URL="fill"
export ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION1_ARGS_URL="fill"

rm -Rf "/tmp/camunda-platform-$HELM_CHART_VERSION"
helm pull camunda/camunda-platform --version "$HELM_CHART_VERSION" --untar --untardir "/tmp/camunda-platform-$HELM_CHART_VERSION"
tree "/tmp/camunda-platform-$HELM_CHART_VERSION"


# Generate the values from the templates
export DOLLAR="\$"
envsubst < kubernetes/camunda-values.yml.tpl > kubernetes/camunda-values.yml

# Cluster 0
envsubst < kubernetes/region0/camunda-values-failover.yml.tpl > kubernetes/region0/camunda-values-failover.yml
envsubst < kubernetes/region0/camunda-values.yml.tpl > kubernetes/region0/camunda-values.yml

helm install $HELM_RELEASE_NAME camunda/camunda-platform --skip-crds \
  --version $HELM_CHART_VERSION \
  --values "/tmp/camunda-platform-$HELM_CHART_VERSION/camunda-platform/openshift/values.yaml" \
  --kube-context $CLUSTER_0 \
  --namespace $CAMUNDA_NAMESPACE_0 \
  --post-renderer bash --post-renderer-args "/tmp/camunda-platform-$HELM_CHART_VERSION/camunda-platform/openshift/patch.sh" \
  -f kubernetes/camunda-values.yml \
  -f kubernetes/region0/camunda-values.yml

# Cluster 1
envsubst < kubernetes/region1/camunda-values-failover.yml.tpl > kubernetes/region1/camunda-values-failover.yml

envsubst < kubernetes/region1/camunda-values.yml.tpl > kubernetes/region1/camunda-values.yml

helm install $HELM_RELEASE_NAME camunda/camunda-platform --skip-crds \
  --version $HELM_CHART_VERSION \
  --values "/tmp/camunda-platform-$HELM_CHART_VERSION/camunda-platform/openshift/values.yaml" \
  --kube-context $CLUSTER_1 \
  --namespace $CAMUNDA_NAMESPACE_1 \
  --post-renderer bash --post-renderer-args "/tmp/camunda-platform-$HELM_CHART_VERSION/camunda-platform/openshift/patch.sh" \
  -f kubernetes/camunda-values.yml \
  -f kubernetes/region1/camunda-values.yml
```

You have now installed C8 in each region. Now we need to configure inter-cluster service communication.

#### Export the services using subctl

To enable inter-cluster service communication, you need to export the services from each cluster. This allows services in one cluster to be accessed from the other cluster.
```bash
echo "Exporting services from $CLUSTER_0 in $CAMUNDA_NAMESPACE_0 using subctl"

for svc in $(kubectl --context "$CLUSTER_0" get svc -n "$CAMUNDA_NAMESPACE_0" -o jsonpath='{.items[*].metadata.name}'); do
    subctl --context "$CLUSTER_0" export service --namespace $CAMUNDA_NAMESPACE_0 $svc
done

echo "Exporting services from $CLUSTER_1 in $CAMUNDA_NAMESPACE_1 using subctl"

for svc in $(kubectl --context "$CLUSTER_1" get svc -n "$CAMUNDA_NAMESPACE_1" -o jsonpath='{.items[*].metadata.name}'); do
    subctl --context "$CLUSTER_1" export service --namespace $CAMUNDA_NAMESPACE_1 $svc
done

```

When services are exported, you may need to wait some time before all the C8 components are up and ready.

### 10. Verify the inter-cluster zeebe status

```bash
kubectl --context "$CLUSTER_0" -n $CAMUNDA_NAMESPACE_0 port-forward services/$HELM_RELEASE_NAME-zeebe-gateway 26500:26500


zbctl status --insecure --address localhost:26500

# You should have 8 brokers
```

### 11. Cleanup

To uninstall the Helm releases and clean up resources:

```bash
helm uninstall $HELM_RELEASE_NAME --kube-context $CLUSTER_0 --namespace $CAMUNDA_NAMESPACE_0
helm uninstall $HELM_RELEASE_NAME --kube-context $CLUSTER_1 --namespace $CAMUNDA_NAMESPACE_1
```

You may also delete the namespaces and the associated data.
