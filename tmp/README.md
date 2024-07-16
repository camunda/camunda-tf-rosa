# Creating Two OpenShift Clusters Across Two Regions

This guide provides step-by-step instructions on creating two OpenShift clusters in two different AWS regions and configuring Camunda 8 on these clusters.

## Prerequisites

Before you start, ensure you have the following tools installed:

- **AWS CLI**: To interact with AWS services.
- **Terraform**: To provision and manage the infrastructure.
- **rosa CLI**: Red Hat OpenShift Service on AWS CLI for managing OpenShift clusters.
- **kubectl**: To manage Kubernetes clusters.
- **helm**: For managing Kubernetes applications.
- **jq**: A lightweight and flexible command-line JSON processor.


## Step-by-Step Instructions

### 1. Define Environment Variables

Set up the environment variables for both regions and clusters:

```bash
# Define the regions
export REGION_0=eu-central-1
export REGION_1=eu-west-1

# Define the cluster names
export CLUSTER_0=cl-oc-1b
export CLUSTER_1=cl-oc-2

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
```

### 2. Set Up Cluster 0

Navigate to the directory for cluster 0 setup and initialize Terraform:

```bash
cd tmp/rosa-hcp-eu-central-1b
export AWS_REGION="$REGION_0"
export RH_TOKEN="yourToken"
export KUBEADMIN_PASSWORD="yourPassword"

terraform init -backend-config="bucket=camunda-tf-rosa" -backend-config="key=tfstate-$CLUSTER_0/$CLUSTER_0.tfstate" -backend-config="region=eu-west-2"

terraform plan -out rosa.plan -var "cluster_name=$CLUSTER_0" -var "htpasswd_password=$KUBEADMIN_PASSWORD" -var "offline_access_token=$RH_TOKEN" -var "replicas=4" -var "vpc_cidr_block=$CLUSTER_0_VPC_CIDR" -var "machine_cidr_block=$CLUSTER_0_MACHINE_CIDR" -var "service_cidr_block=$CLUSTER_0_SERVICE_CIDR" -var "pod_cidr_block=$CLUSTER_0_POD_CIDR"

terraform apply "rosa.plan"
```

### 3. Set Up Cluster 1

Navigate to the directory for cluster 1 setup and initialize Terraform:

```bash
cd tmp/rosa-hcp-eu-west-1
export AWS_REGION="$REGION_1"
export RH_TOKEN="yourToken"
export KUBEADMIN_PASSWORD="yourPassword"

terraform init -backend-config="bucket=camunda-tf-rosa" -backend-config="key=tfstate-$CLUSTER_1/$CLUSTER_1.tfstate" -backend-config="region=eu-west-2"

terraform plan -out rosa.plan -var "cluster_name=$CLUSTER_1" -var "htpasswd_password=$KUBEADMIN_PASSWORD" -var "offline_access_token=$RH_TOKEN" -var "replicas=4" -var "vpc_cidr_block=$CLUSTER_1_VPC_CIDR" -var "machine_cidr_block=$CLUSTER_1_MACHINE_CIDR" -var "service_cidr_block=$CLUSTER_1_SERVICE_CIDR" -var "pod_cidr_block=$CLUSTER_1_POD_CIDR"

terraform apply "rosa.plan"
```

### 4. Retrieve Cluster Information

Retrieve the cluster IDs and API URLs:

```bash
export CLUSTER_0_ID=$(rosa list cluster --output json | jq -r ".[] | select(.name == \"$CLUSTER_0\") | .id")
export CLUSTER_0_API_URL=$(rosa list cluster --output json | jq -r ".[] | select(.name == \"$CLUSTER_0\") | .api.url")
export CLUSTER_1_ID=$(rosa list cluster --output json | jq -r ".[] | select(.name == \"$CLUSTER_1\") | .id")
export CLUSTER_1_API_URL=$(rosa list cluster --output json | jq -r ".[] | select(.name == \"$CLUSTER_1\") | .api.url")
```

### 5. Log In to Clusters

Log in to both clusters:

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

### 6. Configure Ingress

Set up the ingress configuration:

```bash
cd tmp/dual

# Cluster 0 Ingress Configuration
export CLUSTER_0_BASE_DOMAIN=$(rosa list cluster --output json | jq -r ".[] | select(.name == \"$CLUSTER_0\") | .dns.base_domain")
export CLUSTER_0_DOMAIN_PREFIX=$(rosa list cluster --output json | jq -r ".[] | select(.name == \"$CLUSTER_0\") | .domain_prefix")
export CLUSTER_0_DOMAIN="rosa.$CLUSTER_0_DOMAIN_PREFIX.$CLUSTER_0_BASE_DOMAIN"
export CLUSTER_0_APPS_DOMAIN=$(kubectl --context $CLUSTER_0 get IngressController default -n openshift-ingress-operator -o jsonpath='{.spec.domain}')

# Cluster 1 Ingress Configuration
export CLUSTER_1_BASE_DOMAIN=$(rosa list cluster --output json | jq -r ".[] | select(.name == \"$CLUSTER_1\") | .dns.base_domain")
export CLUSTER_1_DOMAIN_PREFIX=$(rosa list cluster --output json | jq -r ".[] | select(.name == \"$CLUSTER_1\") | .domain_prefix")
export CLUSTER_1_DOMAIN="rosa.$CLUSTER_1_DOMAIN_PREFIX.$CLUSTER_1_BASE_DOMAIN"
export CLUSTER_1_APPS_DOMAIN=$(kubectl --context $CLUSTER_1 get IngressController default -n openshift-ingress-operator -o jsonpath='{.spec.domain}')

# Ensure namespaces exist
kubectl --context $CLUSTER_0 get namespace "$CAMUNDA_NAMESPACE_0" || kubectl --context $CLUSTER_0 create namespace "$CAMUNDA_NAMESPACE_0"
kubectl --context $CLUSTER_1 get namespace "$CAMUNDA_NAMESPACE_1" || kubectl --context $CLUSTER_1 create namespace "$CAMUNDA_NAMESPACE_1"
```

### 7. Setup S3 for Elasticsearch

Set up S3 for Elasticsearch:

```bash
cd s3-es
export AWS_REGION="$REGION_0"
terraform init
terraform plan -out "s3.plan" -var "cluster_name=$CLUSTER_0-$CLUSTER_1"
terraform apply "s3.plan"

export AWS_ACCESS_KEY_ES=$(terraform output -raw s3_aws_access_key)
export AWS_SECRET_ACCESS_KEY_ES=$(terraform output -raw s3_aws_secret_access_key)

# Create the secrets in kubectl
cd ..
./create_elasticsearch_secrets.sh

# Cleanup the secrets
unset AWS_ACCESS_KEY_ES
unset AWS_SECRET_ACCESS_KEY_ES
```

### 8. Configure OpenShift Federation Service Mesh


/!\ THIS SECTION IS WORK IN PROGRESS

Set up the OpenShift Federation Service Mesh between the two clusters:

#### 8.1 Install Service Mesh Operators

Follow instructions at https://docs.openshift.com/container-platform/4.16/service_mesh/v2x/installing-ossm.html#ossm-install-ossm-operator_installing-ossm.
Install grafana and jaeger.

#### 8.2 Create Service Mesh Control Planes

Create the Service Mesh Control Planes in both clusters:

```bash
# Cluster 0 Service Mesh Control Plane
cat <<EOF | kubectl --context $CLUSTER_0 apply -f -
apiVersion: maistra.io/v1
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  version: v2.1
  tracing:
    type: Jaeger
  addons:
    grafana:
      enabled: true
EOF

# Cluster 1 Service Mesh Control Plane
cat <<EOF | kubectl --context $CLUSTER_1 apply -f -
apiVersion: maistra.io/v1
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  version: v2.1
  tracing:
    type: Jaeger
  addons:
    grafana:
      enabled: true
EOF
```

#### 8.3 Create Service Mesh Member Rolls

Create the Service Mesh Member Rolls in both clusters:

```bash
# Cluster 0 Service Mesh Member Roll
cat <<EOF | kubectl --context $CLUSTER_0 apply -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
    - $CAMUNDA_NAMESPACE_0
EOF

# Cluster 1 Service Mesh Member Roll
cat <<EOF | kubectl --context $CLUSTER_1 apply -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
    - $CAMUNDA_NAMESPACE_1
EOF
```

#### 8.4 Configure Federation

Enable federation between the two clusters:

```bash
# Cluster 0 Federation Configuration
cat <<EOF | kubectl --context $CLUSTER_0 apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: external-service
  namespace: istio-system
spec:
  hosts:
  - "*.apps.$CLUSTER_1_APPS_DOMAIN"
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
EOF

# Cluster 1 Federation Configuration
cat <<EOF | kubectl --context $CLUSTER_1 apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: external-service
  namespace: istio-system
spec:
  hosts:
  - "*.apps.$CLUSTER_0_APPS_DOMAIN"
  ports:
  - number: 80
    name: http
    protocol: HTTP
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
EOF
```

#### 8.5 Cross cluster service resolution

##### 1. Create Service Entries

Create Service Entries in each cluster to allow them to recognize the services in the other cluster.

```bash
# Define application service names
export SERVICE_NAME="your-service-name"
```

###### Cluster 0 Configuration

```bash
# Define the hostnames and ports for the service in Cluster 1
cat <<EOF | kubectl --context $CLUSTER_0_CONTEXT apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: service-entry-cluster-1
  namespace: $CLUSTER_0_NAMESPACE
spec:
  hosts:
  - "$SERVICE_NAME.$CLUSTER_1_NAMESPACE.svc.cluster.local"
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
EOF
```

###### Cluster 1 Configuration

```bash
# Define the hostnames and ports for the service in Cluster 0
cat <<EOF | kubectl --context $CLUSTER_1_CONTEXT apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: service-entry-cluster-0
  namespace: $CLUSTER_1_NAMESPACE
spec:
  hosts:
  - "$SERVICE_NAME.$CLUSTER_0_NAMESPACE.svc.cluster.local"
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
EOF
```

##### 3. Create Destination Rules

Configure destination rules to ensure proper routing and load balancing.

###### Cluster 0 Configuration

```bash
cat <<EOF | kubectl --context $CLUSTER_0_CONTEXT apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: destination-rule-cluster-1
  namespace: $CLUSTER_0_NAMESPACE
spec:
  host: "$SERVICE_NAME.$CLUSTER_1_NAMESPACE.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
```

###### Cluster 1 Configuration

```bash
cat <<EOF | kubectl --context $CLUSTER_1_CONTEXT apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: destination-rule-cluster-0
  namespace: $CLUSTER_1_NAMESPACE
spec:
  host: "$SERVICE_NAME.$CLUSTER_0_NAMESPACE.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
```

##### 4. Verify the Configuration

Ensure the services are correctly recognized and accessible across clusters. You can do this by deploying a test pod in one cluster and trying to access the service in the other cluster.
Inside the test pod (you can deploy `dual/debug.yml`):

```sh
curl http://$SERVICE_NAME.$CLUSTER_1_NAMESPACE.svc.cluster.local
```

### 9. Prepare for Deployment

Prepare the clusters for Camunda deployment:

```bash
# Set domains for Zeebe forwarder
export CLUSTER_0_ZEEBE_FORWARDER_DOMAIN=$(echo $CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN | sed 's/^\*\.//')
export CLUSTER_1_ZEEBE_FORWARDER_DOMAIN=$(echo $CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN | sed 's/^\*\.//')

export CLUSTER_0_ES_INGRESS_DOMAIN="elastic.$CLUSTER_0_APPS_DOMAIN"
export CLUSTER_1_ES_INGRESS_DOMAIN="elastic.$CLUSTER

_1_APPS_DOMAIN"

./generate_zeebe_helm_values.sh

# Set the output values
export ZEEBE_BROKER_CLUSTER_INITIALCONTACTPOINTS="fill"
export ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION0_ARGS_URL="fill"
export ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION1_ARGS_URL="fill"

# Generate the values from the templates
export DOLLAR="\$"
envsubst < kubernetes/camunda-values.yml.tpl > kubernetes/camunda-values.yml

# Cluster 0
INGRESS_BASE_DOMAIN="$CLUSTER_0_APPS_DOMAIN" \
  ELASTIC_INGRESS_HOSTNAME="$CLUSTER_0_ES_INGRESS_DOMAIN" \
  ZEEBE_FORWARDER_DOMAIN="$CLUSTER_0_ZEEBE_FORWARDER_DOMAIN" \
  envsubst < kubernetes/region0/camunda-values-failover.yml.tpl > kubernetes/region0/camunda-values-failover.yml

INGRESS_BASE_DOMAIN="$CLUSTER_0_APPS_DOMAIN" \
  ELASTIC_INGRESS_HOSTNAME="$CLUSTER_0_ES_INGRESS_DOMAIN" \
  ZEEBE_FORWARDER_DOMAIN="$CLUSTER_0_ZEEBE_FORWARDER_DOMAIN" \
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
INGRESS_BASE_DOMAIN="$CLUSTER_1_APPS_DOMAIN" \
  ELASTIC_INGRESS_HOSTNAME="$CLUSTER_1_ES_INGRESS_DOMAIN" \
  ZEEBE_FORWARDER_DOMAIN="$CLUSTER_1_ZEEBE_FORWARDER_DOMAIN" \
  envsubst < kubernetes/region1/camunda-values-failover.yml.tpl > kubernetes/region1/camunda-values-failover.yml

INGRESS_BASE_DOMAIN="$CLUSTER_1_APPS_DOMAIN" \
  ELASTIC_INGRESS_HOSTNAME="$CLUSTER_1_ES_INGRESS_DOMAIN" \
  ZEEBE_FORWARDER_DOMAIN="$CLUSTER_1_ZEEBE_FORWARDER_DOMAIN" \
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

### Cleanup

To uninstall the Helm releases and clean up resources:

```bash
helm uninstall $HELM_RELEASE_NAME --kube-context $CLUSTER_0 --namespace $CAMUNDA_NAMESPACE_0
helm uninstall $HELM_RELEASE_NAME --kube-context $CLUSTER_1 --namespace $CAMUNDA_NAMESPACE_1
```
