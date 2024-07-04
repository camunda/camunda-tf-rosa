# (optional) Now we need to patch the flow opening (Security Groups)
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
