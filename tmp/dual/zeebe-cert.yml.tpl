---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: zeebe-tls-cert
spec:
  secretName: zeebe-tls-cert
  issuerRef:
     name: letsencryptissuer
     kind: ClusterIssuer
  commonName: "$CLUSTER_ZEEBE_CN_FORWARDER_DOMAIN"
  dnsNames:
  - "$CLUSTER_ZEEBE_CN_FORWARDER_DOMAIN"
  - "$CLUSTER_ZEEBE_FORWARDER_DOMAIN"
