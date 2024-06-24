apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencryptissuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $LETSENCRYPT_EMAIL
    # This key doesn't exist, cert-manager creates it
    privateKeySecretRef:
      name: prod-letsencrypt-issuer-account-key
    solvers:
    - dns01:
        route53:
         hostedZoneID: $HOSTED_ZONE_ID
         region: $HOSTED_ZONE_REGION
         secretAccessKeySecretRef:
           name: ''
