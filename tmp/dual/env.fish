set -x REGION_0 eu-central-1
set -x REGION_1 eu-west-1

set -x CLUSTER_0 cl-oc-1b
set -x CLUSTER_1 cl-oc-2

set -x CLUSTER_0_VPC_CIDR "10.0.0.0/16"
set -x CLUSTER_0_MACHINE_CIDR "10.0.0.0/18"
set -x CLUSTER_0_POD_CIDR "10.0.64.0/18"
set -x CLUSTER_0_SERVICE_CIDR "10.0.128.0/18"

set -x CLUSTER_1_VPC_CIDR "10.1.0.0/16"
set -x CLUSTER_1_MACHINE_CIDR "10.1.0.0/18"
set -x CLUSTER_1_POD_CIDR "10.1.64.0/18"
set -x CLUSTER_1_SERVICE_CIDR "10.1.128.0/18" # TODO: later use this network for the ingress private only

set -x CAMUNDA_NAMESPACE_0 "camunda-$CLUSTER_0"
set -x CAMUNDA_NAMESPACE_0_FAILOVER "$CAMUNDA_NAMESPACE_0-failover"
set -x CAMUNDA_NAMESPACE_1 "camunda-$CLUSTER_1"
set -x CAMUNDA_NAMESPACE_1_FAILOVER "$CAMUNDA_NAMESPACE_1-failover"

# The Helm release name used for installing Camunda 8 in both Kubernetes clusters
set -x HELM_RELEASE_NAME camunda
# renovate: datasource helm depName camunda-platform registryUrl https://helm.camunda.io
set -x HELM_CHART_VERSION 10.1.1

# 0. Setup cluster 0
cd tmp/rosa-hcp-eu-central-1b
set -x AWS_REGION "$REGION_0"
set -x RH_TOKEN "yourToken"
set -x KUBEADMIN_PASSWORD "yourPassword"

terraform init -backend-config="bucket=camunda-tf-rosa" -backend-config="key=tfstate-$CLUSTER_0/$CLUSTER_0.tfstate" -backend-config="region=eu-west-2"

terraform plan -out rosa.plan -var "cluster_name=$CLUSTER_0" -var "htpasswd_password=$KUBEADMIN_PASSWORD" -var "offline_access_token=$RH_TOKEN" -var "replicas=4" -var "vpc_cidr_block=$CLUSTER_0_VPC_CIDR"  -var "machine_cidr_block=$CLUSTER_0_MACHINE_CIDR"  -var "service_cidr_block=$CLUSTER_0_SERVICE_CIDR"  -var "pod_cidr_block=$CLUSTER_0_POD_CIDR"
terraform apply "rosa.plan"

# Setup cluster 1
cd tmp/rosa-hcp-eu-west-1
set -x AWS_REGION "$REGION_1"
set -x RH_TOKEN "yourToken"
set -x KUBEADMIN_PASSWORD "yourPassword"
#
terraform init -backend-config="bucket=camunda-tf-rosa" -backend-config="key=tfstate-$CLUSTER_1/$CLUSTER_1.tfstate" -backend-config="region=eu-west-2"
#
terraform plan -out rosa.plan -var "cluster_name=$CLUSTER_1" -var "htpasswd_password=$KUBEADMIN_PASSWORD" -var "offline_access_token=$RH_TOKEN" -var "replicas=4" -var "vpc_cidr_block=$CLUSTER_1_VPC_CIDR"  -var "machine_cidr_block=$CLUSTER_1_MACHINE_CIDR"  -var "service_cidr_block=$CLUSTER_1_SERVICE_CIDR"  -var "pod_cidr_block=$CLUSTER_1_POD_CIDR"

terraform apply "rosa.plan"


set -x CLUSTER_0_ID (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .id" -r)
set -x CLUSTER_0_API_URL (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .api.url" -r)
set -x CLUSTER_1_ID (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .id" -r)
set -x CLUSTER_1_API_URL (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .api.url"  -r)

# LOGIN CLUSTER 0
rosa grant user cluster-admin --cluster="$CLUSTER_0" --user=kubeadmin
oc login -u kubeadmin "$CLUSTER_0_API_URL" -p "$KUBEADMIN_PASSWORD"
kubectl config delete-context "$CLUSTER_0"
kubectl config rename-context $(oc config current-context) "$CLUSTER_0"
kubectl config use "$CLUSTER_0"

# LOGIN CLUSTER 1
rosa grant user cluster-admin --cluster="$CLUSTER_1" --user=kubeadmin
oc login -u kubeadmin "$CLUSTER_1_API_URL" -p "$KUBEADMIN_PASSWORD"
kubectl config delete-context "$CLUSTER_1"
kubectl config rename-context $(oc config current-context) "$CLUSTER_1"
kubectl config use "$CLUSTER_1"



# I. Configure Ingress

cd tmp/dual

set -x CLUSTER_0_BASE_DOMAIN (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .dns.base_domain" -r)
set -x CLUSTER_0_DOMAIN_PREFIX (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .domain_prefix" -r)
set -x CLUSTER_0_DOMAIN "rosa.$CLUSTER_0_DOMAIN_PREFIX.$CLUSTER_0_BASE_DOMAIN"
set -x CLUSTER_0_APPS_DOMAIN (kubectl --context $CLUSTER_0 get IngressController default -n openshift-ingress-operator -o jsonpath='{.spec.domain}')
set -x CLUSTER_0_ZEEBE_INGRESS_CONTROLLER_DOMAIN "zeebe.$CLUSTER_0_DOMAIN"

set -x CLUSTER_1_BASE_DOMAIN (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .dns.base_domain" -r)
set -x CLUSTER_1_DOMAIN_PREFIX (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .domain_prefix" -r)
set -x CLUSTER_1_DOMAIN "rosa.$CLUSTER_1_DOMAIN_PREFIX.$CLUSTER_1_BASE_DOMAIN"
set -x CLUSTER_1_APPS_DOMAIN (kubectl --context $CLUSTER_1 get IngressController default -n openshift-ingress-operator -o jsonpath='{.spec.domain}')
set -x CLUSTER_1_ZEEBE_INGRESS_CONTROLLER_DOMAIN "zeebe.$CLUSTER_1_DOMAIN"

# pre-req clusters

# then you need to allow wildcard policy at the router level follow: https://access.redhat.com/solutions/5220631
# oc patch --context $CLUSTER_0 ingresscontroller default -n openshift-ingress-operator --type='merge' -p '{"spec": {"routeAdmission": {"wildcardPolicy": "WildcardsAllowed"}}}'
# oc get --context $CLUSTER_0 ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'

# oc patch --context $CLUSTER_1 ingresscontroller default -n openshift-ingress-operator --type='merge' -p '{"spec": {"routeAdmission": {"wildcardPolicy": "WildcardsAllowed"}}}'
# oc get --context $CLUSTER_1 ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'

# define the zeebe wildcard domain
set -x CLUSTER_0_ZEEBE_INGRESS_CONTROLLER_DOMAIN_WILDCARD "*.$CLUSTER_0_ZEEBE_INGRESS_CONTROLLER_DOMAIN"
set -x CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN "*.ptp.$CLUSTER_0_ZEEBE_INGRESS_CONTROLLER_DOMAIN"

set -x CLUSTER_1_ZEEBE_INGRESS_CONTROLLER_DOMAIN_WILDCARD "*.$CLUSTER_1_ZEEBE_INGRESS_CONTROLLER_DOMAIN"
set -x CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN "*.ptp.$CLUSTER_1_ZEEBE_INGRESS_CONTROLLER_DOMAIN"

# create a dedicated ingress controller for zeebe
DOMAIN=(echo "$CLUSTER_0_ZEEBE_INGRESS_CONTROLLER_DOMAIN_WILDCARD" | sed 's/^*\.//') envsubst < ingress-controller/ingress-controller.yml.tpl | kubectl --context $CLUSTER_0 apply -f -
DOMAIN=(echo "$CLUSTER_1_ZEEBE_INGRESS_CONTROLLER_DOMAIN_WILDCARD" | sed 's/^*\.//') envsubst < ingress-controller/ingress-controller.yml.tpl | kubectl --context $CLUSTER_1 apply -f -


set -x CLUSTER_0_ROUTER_ELB_DNS_CNAME_TARGET (kubectl --context $CLUSTER_0 get service router-zeebe-ingress --namespace openshift-ingress -o json | jq '.status.loadBalancer.ingress[0].hostname' -r)
set -x CLUSTER_1_ROUTER_ELB_DNS_CNAME_TARGET (kubectl --context $CLUSTER_1 get service router-zeebe-ingress --namespace openshift-ingress -o json | jq '.status.loadBalancer.ingress[0].hostname' -r)

# Register the DNS CNAME

# apply DNSRecord for the ingress controller
ZEEBE_INGRESS_WILDCARD_DOMAIN=$CLUSTER_0_ZEEBE_INGRESS_CONTROLLER_DOMAIN_WILDCARD \
ROUTER_ELB_DNS_CNAME_TARGET=$CLUSTER_0_ROUTER_ELB_DNS_CNAME_TARGET \
envsubst < zeebe-dnsrecords.yml.tpl | kubectl --context $CLUSTER_0 apply -f -

ZEEBE_INGRESS_WILDCARD_DOMAIN=$CLUSTER_1_ZEEBE_INGRESS_CONTROLLER_DOMAIN_WILDCARD \
ROUTER_ELB_DNS_CNAME_TARGET=$CLUSTER_1_ROUTER_ELB_DNS_CNAME_TARGET \
envsubst < zeebe-dnsrecords.yml.tpl | kubectl --context $CLUSTER_1 apply -f -

# check it as been applied correctly:
oc --context $CLUSTER_0 describe dnsrecord zeebe-route-openshift --namespace openshift-ingress-operator
oc --context $CLUSTER_1 describe dnsrecord zeebe-route-openshift --namespace openshift-ingress-operator

# enable http2 on the ingress controller
# oc --context $CLUSTER_0 annotate ingresscontrollers/default ingress.operator.openshift.io/default-enable-http2=true -n openshift-ingress-operator
# oc --context $CLUSTER_1 annotate ingresscontrollers/default ingress.operator.openshift.io/default-enable-http2=true -n openshift-ingress-operator


# Setup Certificate Manager
oc --context $CLUSTER_0 new-project cert-manager --display-name="Certificate Manager" --description="Project  contains Certificates and Custom Domain related components."
oc --context $CLUSTER_1 new-project cert-manager --display-name="Certificate Manager" --description="Project  contains Certificates and Custom Domain related components."

# Install the operator
oc --context $CLUSTER_0 new-project cert-manager-operator
oc --context $CLUSTER_1 new-project cert-manager-operator

kubectl --context $CLUSTER_0 create -f cert-manager/operator-group.yml
kubectl --context $CLUSTER_1 create -f cert-manager/operator-group.yml

# wait until it is installed
oc --context "$CLUSTER_0" get csv -n cert-manager-operator --watch
oc --context "$CLUSTER_1" get csv -n cert-manager-operator --watch

# For public certificates with Let'sEncrypt, see `LE-certmanager.fish`

# ensure ns exists
kubectl --context $CLUSTER_0 get namespace "$CAMUNDA_NAMESPACE_0" || kubectl --context $CLUSTER_0 create namespace "$CAMUNDA_NAMESPACE_0"
kubectl --context $CLUSTER_1 get namespace "$CAMUNDA_NAMESPACE_1" || kubectl --context $CLUSTER_1 create namespace "$CAMUNDA_NAMESPACE_1"

# now we generate a single self-signed certificate for zeebe broker that will be shared in the two clusters
set -x ZEEBE_SERVICE "$HELM_RELEASE_NAME-zeebe"

ZEEBE_FORWARDER_DOMAIN_CLUSTER_0="$CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" \
ZEEBE_SERVICE_CLUSTER_0="$ZEEBE_SERVICE" \
ZEEBE_NAMESPACE_CLUSTER_0="$CAMUNDA_NAMESPACE_0" \
ZEEBE_FORWARDER_DOMAIN_CLUSTER_1="$CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" \
ZEEBE_SERVICE_CLUSTER_1="$ZEEBE_SERVICE" \
ZEEBE_NAMESPACE_CLUSTER_1="$CAMUNDA_NAMESPACE_1" \
envsubst < zeebe-broker-certs.yml.tpl | kubectl --context $CLUSTER_0 --namespace "$CAMUNDA_NAMESPACE_0" apply -f -

# wait until the certificate are ready
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get certificate.cert-manager.io/zeebe-local-tls-cert --watch

# TODO: share this certificate on CLUSTER_1

# TODO: concatenante : https://github.com/camunda/camunda-platform-helm/blob/f5c12f13a4496746d0444b866e40499e35a0857b/charts/camunda-platform-latest/templates/zeebe/configmap.yaml#L75

# now deploy the caddy reverse proxy for zeebe for each cluster

## Cluster 0

ZEEBE_NAMESPACE="$CAMUNDA_NAMESPACE_0" \
ZEEBE_SERVICE="$ZEEBE_SERVICE" \
ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN="$CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" \
ZEEBE_PTP_INGRESS_WILDCARD_ROUTE_DOMAIN=$(echo "$CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" | sed 's/^*\./wildcard./') \
ZEEBE_DOMAIN_DEPTH=(echo "$CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" | awk -F"." '{print NF-1}' ) \
envsubst < caddy.yml.tpl | kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" apply -f -

# check everythin is okay
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get configmap/caddy-config
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get service/caddy-reverse-zeebe
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get deployment.apps/caddy
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get ingress.networking.k8s.io/caddy-reverse-zeebe-ingress

## Cluster 1

ZEEBE_NAMESPACE="$CAMUNDA_NAMESPACE_1" \
ZEEBE_SERVICE="$ZEEBE_SERVICE" \
ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN="$CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" \
ZEEBE_PTP_INGRESS_WILDCARD_ROUTE_DOMAIN=$(echo "$CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" | sed 's/^*\./wildcard./') \
ZEEBE_DOMAIN_DEPTH=(echo "$CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" | awk -F"." '{print NF-1}' ) \
envsubst < caddy.yml.tpl | kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" apply -f -

# check everythin is okay
kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" get configmap/caddy-config
kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" get service/caddy-reverse-zeebe
kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" get deployment.apps/caddy
kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" get ingress.networking.k8s.io/caddy-reverse-zeebe-ingress

# II. Setup S3 for ES

cd s3-es
set -x AWS_REGION "$REGION_0"
terraform init
terraform plan -out "s3.plan" -var "cluster_name=$CLUSTER_0-$CLUSTER_1"
terraform apply "s3.plan"

set -x AWS_ACCESS_KEY_ES (terraform output -raw s3_aws_access_key)
set -x AWS_SECRET_ACCESS_KEY_ES (terraform output -raw s3_aws_secret_access_key)

# create the secrets in kubectl
cd ..
./create_elasticsearch_secrets.sh

# cleanup the secrets
set -x AWS_ACCESS_KEY_ES
set -x AWS_SECRET_ACCESS_KEY_ES

# IV. Prepare for deployment
set -x CLUSTER_0_ZEEBE_FORWARDER_DOMAIN (echo $CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN | sed 's/^\*\.//')
set -x CLUSTER_1_ZEEBE_FORWARDER_DOMAIN (echo $CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN | sed 's/^\*\.//')

set -x CLUSTER_0_ES_INGRESS_DOMAIN "elastic.$CLUSTER_0_APPS_DOMAIN"
set -x CLUSTER_1_ES_INGRESS_DOMAIN "elastic.$CLUSTER_1_APPS_DOMAIN"

./generate_zeebe_helm_values.sh

# set the output values

set -x ZEEBE_BROKER_CLUSTER_INITIALCONTACTPOINTS "fill"
set -x ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION0_ARGS_URL "fill"
set -x ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION1_ARGS_URL "fill"

# Generate the values from the templates

# Global

# Make sure to set CHART_VERSION to match the chart version you want to install.
helm pull camunda/camunda-platform --version "$HELM_CHART_VERSION" --untar --untardir "/tmp/camunda-platform-$HELM_CHART_VERSION"


set -x DOLLAR "\$"
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
  --values "/tmp/camunda-platform-$HELM_CHART_VERSION/camunda-platform/openshift/values.yaml"   \
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
  --values "/tmp/camunda-platform-$HELM_CHART_VERSION/camunda-platform/openshift/values.yaml"   \
  --kube-context $CLUSTER_1 \
  --namespace $CAMUNDA_NAMESPACE_1 \
  --post-renderer bash --post-renderer-args "/tmp/camunda-platform-$HELM_CHART_VERSION/camunda-platform/openshift/patch.sh" \
  -f kubernetes/camunda-values.yml \
  -f kubernetes/region1/camunda-values.yml


# Cleanup with

helm uninstall $HELM_RELEASE_NAME --kube-context $CLUSTER_0 --namespace $CAMUNDA_NAMESPACE_0
helm uninstall $HELM_RELEASE_NAME --kube-context $CLUSTER_1 --namespace $CAMUNDA_NAMESPACE_1
