---
global:
  multiregion:
    # unique id of the region. MUST be an integer starting at 0 for computation. With 2 regions, you would have region ids 0 and 1.
    regionId: 0


zeebeGateway:
  ingress:
    rest:
      enabled: true
      className: ""
      host: "zeebe.$INGRESS_BASE_DOMAIN"
    grpc:
      enabled: true
      className: ""
      host: "zeebe-grpc.$INGRESS_BASE_DOMAIN" # TODO: check gateway conf
      tls:
        enabled: true
      annotations:
        route.openshift.io/termination: reencrypt
        route.openshift.io/destination-ca-certificate-secret: zeebe-tls-cert
  env:
  - name: ZEEBE_GATEWAY_CLUSTER_MESSAGECOMPRESSION
    value: "GZIP"
  - name: ZEEBE_GATEWAY_CLUSTER_MEMBERSHIP_PROBETIMEOUT
    value: "500ms"
  - name: ZEEBE_GATEWAY_CLUSTER_MEMBERSHIP_PROBEINTERVAL
    value: "2s"
  - name: ZEEBE_GATEWAY_SECURITY_ENABLED
    value: "true"
  - name: ZEEBE_GATEWAY_SECURITY_CERTIFICATECHAINPATH
    value: /usr/local/zeebe/config/tls.crt
  - name: ZEEBE_GATEWAY_SECURITY_PRIVATEKEYPATH
    value: /usr/local/zeebe/config/tls.key
  extraVolumeMounts:
    - name: certificate
      mountPath: /usr/local/zeebe/config/tls.crt
      subPath: tls.crt
    - name: key
      mountPath: /usr/local/zeebe/config/tls.key
      subPath: tls.key
  extraVolumes:
    - name: certificate
      secret:
        secretName: zeebe-local-tls-cert
        items:
          - key: tls.crt
            path: tls.crt
        defaultMode: 420
    - name: key
      secret:
        secretName: zeebe-local-tls-cert
        items:
          - key: tls.key
            path: tls.key
        defaultMode: 420

zeebe:
  env:
  - name: ZEEBE_BROKER_DATA_SNAPSHOTPERIOD
    value: "5m"
  - name: ZEEBE_BROKER_DATA_DISKUSAGECOMMANDWATERMARK
    value: "0.85"
  - name: ZEEBE_BROKER_DATA_DISKUSAGEREPLICATIONWATERMARK
    value: "0.87"
  - name: ZEEBE_BROKER_CLUSTER_INITIALCONTACTPOINTS
    value: "$ZEEBE_BROKER_CLUSTER_INITIALCONTACTPOINTS"
  - name: ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION0_CLASSNAME
    value: "io.camunda.zeebe.exporter.ElasticsearchExporter"
  - name: ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION0_ARGS_URL
    value: "$ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION0_ARGS_URL"
  - name: ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION1_CLASSNAME
    value: "io.camunda.zeebe.exporter.ElasticsearchExporter"
  - name: ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION1_ARGS_URL
    value: "$ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION1_ARGS_URL"
  # Enable JSON logging for Google Cloud Stackdriver
  - name: ZEEBE_LOG_APPENDER
    value: Stackdriver
  - name: ZEEBE_LOG_STACKDRIVER_SERVICENAME
    value: zeebe
  - name: ZEEBE_LOG_STACKDRIVER_SERVICEVERSION
    valueFrom:
      fieldRef:
        fieldPath: metadata.namespace
  - name: ZEEBE_BROKER_CLUSTER_MEMBERSHIP_PROBETIMEOUT
    value: "500ms"
  - name: ZEEBE_BROKER_CLUSTER_MEMBERSHIP_PROBEINTERVAL
    value: "2s"
  - name: ZEEBE_BROKER_EXPERIMENTAL_RAFT_SNAPSHOTREQUESTTIMEOUT
    value: "10s"
  - name: ZEEBE_BROKER_CLUSTER_MESSAGECOMPRESSION
    value: "GZIP"
  - name: ZEEBE_BROKER_BACKPRESSURE_AIMD_REQUESTTIMEOUT
    value: "1s"
  - name: ZEEBE_BROKER_NETWORK_ADVERTISEDHOST
    value: ${DOLLAR}(K8S_NAME).$ZEEBE_FORWARDER_DOMAIN
  - name: ZEEBE_BROKER_NETWORK_SECURITY_ENABLED
    value: "true"
  - name: ZEEBE_BROKER_NETWORK_SECURITY_CERTIFICATECHAINPATH
    value: "/usr/local/zeebe/config/tls.crt"
  - name: ZEEBE_BROKER_NETWORK_SECURITY_PRIVATEKEYPATH
    value: "/usr/local/zeebe/config/tls.key"
  - name: ZEEBE_LOG_LEVEL
    value: "debug"
  - name: ATOMIX_LOG_LEVEL
    value: "debug"
  extraVolumeMounts:
    - name: certificate
      mountPath: /usr/local/zeebe/config/tls.crt
      subPath: tls.crt
    - name: key
      mountPath: /usr/local/zeebe/config/tls.key
      subPath: tls.key
  extraVolumes:
    - name: certificate
      secret:
        secretName: zeebe-local-tls-cert
        items:
          - key: tls.crt
            path: tls.crt
        defaultMode: 420
    - name: key
      secret:
        secretName: zeebe-local-tls-cert
        items:
          - key: tls.key
            path: tls.key
        defaultMode: 420

webModeler:
  ingress:
    enabled: true
    className: ""
    webapp:
      host: "modeler.$INGRESS_BASE_DOMAIN"
    websockets:
      host: "modeler-ws.$INGRESS_BASE_DOMAIN"

console:
  ingress:
    enabled: true
    className: ""
    host: "console.$INGRESS_BASE_DOMAIN"

elasticsearch:
  ingress:
    enabled: true
    ingressClassName: ""
    hostname: "$ELASTIC_INGRESS_HOSTNAME"
