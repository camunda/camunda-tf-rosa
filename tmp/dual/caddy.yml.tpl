# Use envsubst https://stackoverflow.com/a/56009991
# envsubst < file.yaml.tpl > file.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: caddy-config
data:
  Caddyfile: |
    {
        auto_https off
        debug

        https_port 8443

        servers {
          protocols h1 h2 h3
        }
    }

    https://$ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN:8443 {
        #   domain level:     7        6     5       4    3    2       1        0
        #                sample-nginx.zeebe.rosa.cl-oc-2.dlyd.p3.openshiftapps.com
        tls /etc/caddy/zeebe/tls.crt /etc/caddy/zeebe/tls.key
        method h2
        reverse_proxy {http.request.host.labels.$ZEEBE_DOMAIN_DEPTH}.$ZEEBE_SERVICE.$ZEEBE_NAMESPACE.svc.cluster.local:26502
    }
---
apiVersion: v1
kind: Service
metadata:
  name: caddy-reverse-zeebe
spec:
  selector:
    app: caddy-reverse-zeebe
  ports:
  - protocol: TCP
    port: 8433
    targetPort: 8433
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: caddy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: caddy-reverse-zeebe
  template:
    metadata:
      labels:
        app: caddy-reverse-zeebe
    spec:
      containers:
      - name: caddy-reverse-zeebe
        image: quay.io/cloudservices/caddy-ubi # todo: find a better source
        command: ["/usr/bin/caddy"]
        args: ["run", "--config", "/opt/app-root/src/Caddyfile"]
        volumeMounts:
        - name: caddy-config
          mountPath: /opt/app-root/src/
        - name: caddy-local-config
          mountPath: /.config
        - name: caddy-local
          mountPath: /.local
        - name: zeebe-tls
          mountPath: /etc/caddy/zeebe
          readOnly: true
        ports:
        - containerPort: 8443
      volumes:
      - name: caddy-config
        configMap:
          name: caddy-config
      - name: caddy-local
        emptyDir: {}
      - name: caddy-local-config
        emptyDir: {}
      - name: zeebe-tls
        secret:
          secretName: zeebe-tls-cert
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: caddy-reverse-zeebe-ingress
  labels:
    type: zeebe-router
  annotations:
    route.openshift.io/termination: reencrypt
    route.openshift.io/destination-ca-certificate-secret: zeebe-tls-cert
spec:
  rules:
  - host: "$ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: caddy-reverse-zeebe
            port:
              number: 8443
  tls:
  - hosts:
    - "$ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN"
    secretName: zeebe-tls-cert
# apiVersion: route.openshift.io/v1
# kind: Route
# metadata:
#   name: caddy-reverse-zeebe-route
#   labels:
#     type: zeebe-router
# spec:
#   host: "$ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN"
#   to:
#     kind: Service
#     name: caddy-reverse-zeebe
#     weight: 100
#   port:
#     targetPort: 8443
#   tls:
#     termination: passthrough
#   wildcardPolicy: Subdomain
