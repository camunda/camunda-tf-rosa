# Use envsubst https://stackoverflow.com/a/56009991
# envsubst < file.yaml.tpl > file.yaml
---
apiVersion: ingress.operator.openshift.io/v1
kind: DNSRecord
metadata:
  labels:
    ingresscontroller.operator.openshift.io/owning-ingresscontroller: default
  name: zeebe-route-openshift
  namespace: openshift-ingress-operator
spec:
  # openshift.example.com is my base domain and ocp45 is my cluster ID
  dnsName: '$ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN.'
  recordTTL: 30
  recordType: CNAME
  targets:
  # Target should be the ELB DNS and all worker and master instances should be added to this ELB
  - $ROUTER_ELB_DNS_CNAME_TARGET
