---
global:
  multiregion:
    installationType: failOver
    # id of the region that has failed and should be impersonated
    regionId: 1
connectors:
  enabled: false
operate:
  enabled: false
tasklist:
  enabled: false
zeebe:
  env:
  # the entire env array is copied from camunda-values.yaml
  # because Helm cannot merge arrays from multiple value files
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
  # Changing the exporter for the lost ES instance to a throw-away ES instance
  # to allow the other exporter to continue exporting to the surviving ES
  # and keep counting sequences in preparation for ES snapshot restore
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

zeebeGateway:
  ingress:
    rest:
      enabled: true
      className: ""
      host: "zeebe.$INGRESS_BASE_DOMAIN"
    grpc:
      enabled: true
      className: ""
      host: "zeebe-grpc.$INGRESS_BASE_DOMAIN"

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