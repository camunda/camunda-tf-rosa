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


TODO: update cluster creation steps and submariner based on submariner.fish

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

### 7. Install OpenShift ACM and Submariner

TODO: document

### 8. Setup S3 for Elasticsearch

Set up S3 for Elasticsearch:

```bash
cd s3-es
export AWS_REGION="$REGION_0"
terraform init  -backend-config="bucket=camunda-tf-rosa" -backend-config="key=tfstate-$CLUSTER_0-$CLUSTER_1-s3/bucket.tfstate" -backend-config="region=eu-west-2"
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

### 9. Prepare for Deployment

Prepare the clusters for Camunda deployment:

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

#### Export the services using subctl

In order to access the different services from each cluster, we need to export them:
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

### Verify

```bash
kubectl --context "$CLUSTER_0" -n $CAMUNDA_NAMESPACE_0 port-forward services/$HELM_RELEASE_NAME-zeebe-gateway 26500:26500


zbctl status --insecure --address localhost:26500

# You should have 8 brokers
```

### Cleanup

To uninstall the Helm releases and clean up resources:

```bash
helm uninstall $HELM_RELEASE_NAME --kube-context $CLUSTER_0 --namespace $CAMUNDA_NAMESPACE_0
helm uninstall $HELM_RELEASE_NAME --kube-context $CLUSTER_1 --namespace $CAMUNDA_NAMESPACE_1
```
