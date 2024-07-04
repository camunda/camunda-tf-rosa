apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: zeebe-local-tls-cert
spec:
  secretName: zeebe-local-tls-cert
  duration: 2160h # 90d
  renewBefore: 360h # 15d
  commonName: "$ZEEBE_FORWARDER_DOMAIN_CLUSTER_0"
  dnsNames:
  - "*.$ZEEBE_SERVICE_CLUSTER_0.$ZEEBE_NAMESPACE_CLUSTER_0.svc"
  - "*.$ZEEBE_SERVICE_CLUSTER_0.$ZEEBE_NAMESPACE_CLUSTER_0.svc.cluster.local"
  - "*.$ZEEBE_NAMESPACE_CLUSTER_0.pod"
  - "*.$ZEEBE_NAMESPACE_CLUSTER_0.pod.cluster.local"
  - "$ZEEBE_FORWARDER_DOMAIN_CLUSTER_0"
  issuerRef:
    name: selfsigned-issuer
    kind: Issuer
# TODO: this file should deleted in favor of the same with the two clusters
