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
  commonName: "$ZEEBE_FORWARDER_DOMAIN"
  dnsNames:
  - "*.$ZEEBE_SERVICE.$ZEEBE_NAMESPACE.svc"
  - "*.$ZEEBE_SERVICE.$ZEEBE_NAMESPACE.svc.cluster.local"
  - "*.$ZEEBE_NAMESPACE.pod"
  - "*.$ZEEBE_NAMESPACE.pod.cluster.local"
  - "$ZEEBE_FORWARDER_DOMAIN"
  issuerRef:
    name: selfsigned-issuer
    kind: Issuer
