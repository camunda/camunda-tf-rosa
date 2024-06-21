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
set -x CLUSTER_1_SERVICE_CIDR "10.1.128.0/18"

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
kubectl config rename-context $(oc config current-context) "$CLUSTER_0"
kubectl config use "$CLUSTER_0"

# LOGIN CLUSTER 1
rosa grant user cluster-admin --cluster="$CLUSTER_1" --user=kubeadmin
oc login -u kubeadmin "$CLUSTER_1_API_URL" -p "$KUBEADMIN_PASSWORD"
kubectl config rename-context $(oc config current-context) "$CLUSTER_1"
kubectl config use "$CLUSTER_1"

# Now we need to patch the flow opening (Security Groups)
# 0. cd peering
# 1. Edit vpc-peering.tf, set your values
# 2. terraform init
# 3. terraform apply

# Notes:
# no dns in the kube-system
# DNS LB setup works only on AWS 'ROSA OK'
# https://docs.camunda.io/docs/next/self-managed/setup/deploy/amazon/amazon-eks/dual-region/#coredns-configuration
#
# Also the dns config is managed by the operator https://docs.openshift.com/container-platform/4.9/networking/dns-operator.html
# > You are a cluster administrator and have reported an issue with CoreDNS, but need to apply a workaround until the issue is fixed. You can set the managementState field of the DNS Operator to Unmanaged to apply the workaround.
#
# no force TCP option available

# Test dns chaining => scc no set correcttly

# 0. cd tmp/dual
# 1.1 kubectl --context $CLUSTER_0 apply -f internal-dns-lb.yml
# 1.2 kubectl --context $CLUSTER_1 apply -f internal-dns-lb.yml
# 2.1 kubectl --context $CLUSTER_0 apply -f debug.yml
# 2.2 kubectl --context $CLUSTER_1 apply -f debug.yml
# 3. (optional) Shell into the created debug container
# 4. (optional)  Retrieve the ELB : kubectl --context $CLUSTER_0 --namespace=openshift-dns get svc
# 5. (optional) perform a udp dns request:
# dig google.fr @a59ec8ba767d34d08b12728db7c17117-380671b6a5fa3f94.elb.eu-central-1.amazonaws.com
# dig dns-default.openshift-dns @a59ec8ba767d34d08b12728db7c17117-380671b6a5fa3f94.elb.eu-central-1.amazonaws.com
# root@ubuntu-with-nmap:/# dig dns-default.openshift-dns.svc.cluster.local @a59ec8ba767d34d08b12728db7c17117-380671b6a5fa3f94.elb.eu-central-1.amazonaws.com
# example output
# ; <<>> DiG 9.18.24-0ubuntu5-Ubuntu <<>> dns-default.openshift-dns.svc.cluster.local @a59ec8ba767d34d08b12728db7c17117-380671b6a5fa3f94.elb.eu-central-1.amazonaws.com
# ;; global options: +cmd
# ;; Got answer:
# ;; WARNING: .local is reserved for Multicast DNS
# ;; You are currently testing what happens when an mDNS query is leaked to DNS
# ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12126
# ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
# ;; WARNING: recursion requested but not available

# ;; OPT PSEUDOSECTION:
# ; EDNS: version: 0, flags:; udp: 1232
# ; COOKIE: 4c3bcec06cb05eeb (echoed)
# ;; QUESTION SECTION:
# ;dns-default.openshift-dns.svc.cluster.local. IN	A

# ;; ANSWER SECTION:
# dns-default.openshift-dns.svc.cluster.local. 5 IN A 172.30.0.10

# ;; Query time: 5 msec
# ;; SERVER: 10.65.57.252#53(a59ec8ba767d34d08b12728db7c17117-380671b6a5fa3f94.elb.eu-central-1.amazonaws.com) (UDP)
# ;; WHEN: Tue Jun 18 16:26:17 UTC 2024
# ;; MSG SIZE  rcvd: 143

# When you have confirmed that it works correctly locally, you can do cross region dns queries (just use the opposite ELB server name)

# root@ubuntu-with-nmap:/# dig dns-default.openshift-dns.svc.cluster.local @aaa79614aa08e4f1aa495aecee450fa4-9c9ac9a4fd16ee2d.elb.eu-central-1.amazonaws.com

# ; <<>> DiG 9.18.24-0ubuntu5-Ubuntu <<>> dns-default.openshift-dns.svc.cluster.local @aaa79614aa08e4f1aa495aecee450fa4-9c9ac9a4fd16ee2d.elb.eu-central-1.amazonaws.com
# ;; global options: +cmd
# ;; Got answer:
# ;; WARNING: .local is reserved for Multicast DNS
# ;; You are currently testing what happens when an mDNS query is leaked to DNS
# ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 54433
# ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
# ;; WARNING: recursion requested but not available

# ;; OPT PSEUDOSECTION:
# ; EDNS: version: 0, flags:; udp: 1232
# ; COOKIE: d86c1ec1c99f97ca (echoed)
# ;; QUESTION SECTION:
# ;dns-default.openshift-dns.svc.cluster.local. IN	A

# ;; ANSWER SECTION:
# dns-default.openshift-dns.svc.cluster.local. 5 IN A 172.30.0.10

# ;; Query time: 6 msec
# ;; SERVER: 10.66.44.86#53(aaa79614aa08e4f1aa495aecee450fa4-9c9ac9a4fd16ee2d.elb.eu-central-1.amazonaws.com) (UDP)
# ;; WHEN: Tue Jun 18 16:46:16 UTC 2024
# ;; MSG SIZE  rcvd: 143

# 6. Now we will configure the forwarding of the requests from the cluster DNS Operator:
# python generate_core_dns_entry.py

# Now we will test the dns chaining: ./test_dns_chaining.sh
# this one use unprivileged nginx

# Note: it only works in k9s...

################ New method with ingress:


# I. Configure Ingress

cd tmp/dual

set -x CLUSTER_0_BASE_DOMAIN (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .dns.base_domain" -r)
set -x CLUSTER_0_DOMAIN_PREFIX (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .domain_prefix" -r)
set -x CLUSTER_0_DOMAIN "rosa.$CLUSTER_0_DOMAIN_PREFIX.$CLUSTER_0_BASE_DOMAIN"
set -x CLUSTER_0_APPS_DOMAIN (kubectl --context $CLUSTER_0 get IngressController default -n openshift-ingress-operator -o jsonpath='{.spec.domain}')

set -x CLUSTER_1_BASE_DOMAIN (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .dns.base_domain" -r)
set -x CLUSTER_1_DOMAIN_PREFIX (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .domain_prefix" -r)
set -x CLUSTER_1_DOMAIN "rosa.$CLUSTER_1_DOMAIN_PREFIX.$CLUSTER_1_BASE_DOMAIN"
set -x CLUSTER_1_APPS_DOMAIN (kubectl --context $CLUSTER_1 get IngressController default -n openshift-ingress-operator -o jsonpath='{.spec.domain}')

# pre-req clusters

# then you need to allow wildcard policy at the router level follow: https://access.redhat.com/solutions/5220631
oc patch --context $CLUSTER_0 ingresscontroller default -n openshift-ingress-operator --type='merge' -p '{"spec": {"routeAdmission": {"wildcardPolicy": "WildcardsAllowed"}}}'
oc get --context $CLUSTER_0 ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'

oc patch --context $CLUSTER_1 ingresscontroller default -n openshift-ingress-operator --type='merge' -p '{"spec": {"routeAdmission": {"wildcardPolicy": "WildcardsAllowed"}}}'
oc get --context $CLUSTER_1 ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'

# define the zeebe wildcard domain
set -x CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN "*.zeebe.$CLUSTER_0_DOMAIN"
set -x CLUSTER_0_ROUTER_ELB_DNS_CNAME_TARGET (kubectl --context $CLUSTER_0 get service router-default --namespace openshift-ingress -o json | jq '.status.loadBalancer.ingress[0].hostname' -r)

set -x CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN "*.zeebe.$CLUSTER_1_DOMAIN"
set -x CLUSTER_1_ROUTER_ELB_DNS_CNAME_TARGET (kubectl --context $CLUSTER_1 get service router-default --namespace openshift-ingress -o json | jq '.status.loadBalancer.ingress[0].hostname' -r)

# Register the DNS CNAME

# apply DNSRecord
ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN=$CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN \
  ROUTER_ELB_DNS_CNAME_TARGET=$CLUSTER_0_ROUTER_ELB_DNS_CNAME_TARGET \
  envsubst < caddy-openshift-reqs.yml.tpl | kubectl --context $CLUSTER_0 apply -f -

ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN=$CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN \
  ROUTER_ELB_DNS_CNAME_TARGET=$CLUSTER_1_ROUTER_ELB_DNS_CNAME_TARGET \
  envsubst < caddy-openshift-reqs.yml.tpl | kubectl --context $CLUSTER_1 apply -f -

# check it as been applied correctly:
oc --context $CLUSTER_0 describe dnsrecord zeebe-route-openshift --namespace openshift-ingress-operator
oc --context $CLUSTER_1 describe dnsrecord zeebe-route-openshift --namespace openshift-ingress-operator

# enable http2 on the ingress controller
oc --context $CLUSTER_0 annotate ingresscontrollers/default ingress.operator.openshift.io/default-enable-http2=true -n openshift-ingress-operator
oc --context $CLUSTER_1 annotate ingresscontrollers/default ingress.operator.openshift.io/default-enable-http2=true -n openshift-ingress-operator

# ensure ns exists
kubectl --context $CLUSTER_0 get namespace "$CAMUNDA_NAMESPACE_0" || kubectl --context $CLUSTER_0 create namespace "$CAMUNDA_NAMESPACE_0"
kubectl --context $CLUSTER_1 get namespace "$CAMUNDA_NAMESPACE_1" || kubectl --context $CLUSTER_1 create namespace "$CAMUNDA_NAMESPACE_1"


# now deploy the caddy reverse proxy for zeebe for each cluster

## Cluster 0

ZEEBE_NAMESPACE="$CAMUNDA_NAMESPACE_0" \
  ZEEBE_SERVICE="$HELM_RELEASE_NAME-zeebe" \
  ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN="$CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" \
  ZEEBE_DOMAIN_DEPTH=(echo "$CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" | awk -F"." '{print NF-1}' ) \
  envsubst < caddy.yml.tpl | kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" apply -f -

# check everythin is okay
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get configmap/caddy-config
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get service/caddy-reverse-zeebe
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get deployment.apps/caddy
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get ingress.networking.k8s.io/caddy-reverse-zeebe-ingress

## Cluster 1


ZEEBE_NAMESPACE="$CAMUNDA_NAMESPACE_1" \
  ZEEBE_SERVICE="$HELM_RELEASE_NAME-zeebe" \
  ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN="$CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" \
  ZEEBE_DOMAIN_DEPTH=(echo "$CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" | awk -F"." '{print NF-1}' ) \
  envsubst < caddy.yml.tpl | kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" apply -f -

# check everythin is okay
kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" get configmap/caddy-config
kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" get service/caddy-reverse-zeebe
kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" get deployment.apps/caddy
kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" get ingress.networking.k8s.io/caddy-reverse-zeebe-ingress

# II. Setup S3 for ES

cd s3-es
set -x AWS_REGION "$REGION_O"
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

set -x DOLLAR "\$"
envsubst < kubernetes/camunda-values.yml.tpl > kubernetes/camunda-values.yml


# Make sure to set CHART_VERSION to match the chart version you want to install.
helm pull camunda/camunda-platform --version "$HELM_CHART_VERSION" --untar --untardir "/tmp/camunda-platform-$HELM_CHART_VERSION"

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
