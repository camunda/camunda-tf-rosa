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
    }

    http://$ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN:8080 {
        #   domain level:     7        6     5       4    3    2       1        0
        #                sample-nginx.zeebe.rosa.cl-oc-2.dlyd.p3.openshiftapps.com
        reverse_proxy {http.request.host.labels.$ZEEBE_DOMAIN_DEPTH}.$ZEEBE_SERVICE.$ZEEBE_NAMESPACE.svc.cluster.local:$ZEEBE_SERVICE_PORT
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
    port: 8080
    targetPort: 8080
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
        ports:
        - containerPort: 8080
      volumes:
      - name: caddy-config
        configMap:
          name: caddy-config
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: caddy-reverse-zeebe-ingress
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
              number: 8080
