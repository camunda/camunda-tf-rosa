set -x REGION_0 eu-central-1
set -x REGION_1 eu-west-2

set -x CLUSTER_0 cl-oc-1b
set -x CLUSTER_1 cl-oc-2

set -x CLUSTER_0_VPC_CIDR "10.65.0.0/16"
set -x CLUSTER_1_VPC_CIDR "10.64.0.0/16"

set -x CAMUNDA_NAMESPACE_0 "camunda-$CLUSTER_0"
set -x CAMUNDA_NAMESPACE_0_FAILOVER "$CAMUNDA_NAMESPACE_0-failover"
set -x CAMUNDA_NAMESPACE_1 "camunda-$CLUSTER_1"
set -x CAMUNDA_NAMESPACE_1_FAILOVER "$CAMUNDA_NAMESPACE_1-failover"

# The Helm release name used for installing Camunda 8 in both Kubernetes clusters
set -x HELM_RELEASE_NAME camunda
# renovate: datasource helm depName camunda-platform registryUrl https://helm.camunda.io
set -x HELM_CHART_VERSION 10.1.0

# Setup cluster 0
# cd tmp/rosa-hcp-eu-central-1b
# set -x AWS_REGION "$REGION_0"
# set -x RH_TOKEN "yourToken"
# set -x KUBEADMIN_PASSWORD "yourPassword"
#
# terraform init -backend-config="bucket=camunda-tf-rosa" -backend-config="key=tfstate-$CLUSTER_0/$CLUSTER_0.tfstate" -backend-config="region=eu-west-2"
#
# terraform plan -out rosa.plan -var "cluster_name=$CLUSTER_0" -var "htpasswd_password=$KUBEADMIN_PASSWORD" -var "offline_access_token=$RH_TOKEN" -var "replicas=4" -var "vpc_cidr_block=$CLUSTER_0_VPC_CIDR"
#
# terraform apply "rosa.plan"

# Setup cluster 1
# cd tmp/rosa-hcp-eu-west-2
# set -x AWS_REGION "$REGION_1"
# set -x RH_TOKEN "yourToken"
# set -x KUBEADMIN_PASSWORD "yourPassword"
#
# terraform init -backend-config="bucket=camunda-tf-rosa" -backend-config="key=tfstate-$CLUSTER_1/$CLUSTER_1.tfstate" -backend-config="region=eu-west-2"
#
# terraform plan -out rosa.plan -var "cluster_name=$CLUSTER_1" -var "htpasswd_password=$KUBEADMIN_PASSWORD" -var "offline_access_token=$RH_TOKEN" -var "replicas=4" -var "vpc_cidr_block=$CLUSTER_1_VPC_CIDR"
#
# terraform apply "rosa.plan"


set -x CLUSTER_0_ID (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .id" -r)
set -x CLUSTER_0_API_URL (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_0\") | .api.url" -r)
set -x CLUSTER_1_ID (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .id" -r)
set -x CLUSTER_1_API_URL (rosa list cluster --output json | jq ".[] | select(.name == \"$CLUSTER_1\") | .api.url"  -r)

# LOGIN CLUSTER 0
# rosa grant user cluster-admin --cluster="$CLUSTER_0" --user=kubeadmin
# oc login -u kubeadmin "$CLUSTER_0_API_URL"
# kubectl config rename-context $(oc config current-context) "$CLUSTER_0"
# kubectl config use "$CLUSTER_0"

# LOGIN CLUSTER 1
# rosa grant user cluster-admin --cluster="$CLUSTER_1" --user=kubeadmin
# oc login -u kubeadmin "$CLUSTER_1_API_URL"
# kubectl config rename-context $(oc config current-context) "$CLUSTER_1"
# kubectl config use "$CLUSTER_1"

# Now we need to patch the flow opening (Security Groups)
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
# 3. Shell into the created debug container
# 4. Retrieve the ELB : kubectl --context $CLUSTER_0 --namespace=openshift-dns get svc
# 5. perform a udp dns request:
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

# Note: if we loose a node, the absence of the usage of the lb, make it hard to update..