---
# Chart values for the Camunda Platform 8 Helm chart.
# This file deliberately contains only the values that differ from the defaults.
# For changes and documentation, use your favorite diff tool to compare it with:
# https://github.com/camunda/camunda-platform-helm/blob/main/charts/camunda-platform/values.yaml

global:
  # Multiregion options for Zeebe
  #
  ## WARNING: In order to get your multi-region setup covered by Camunda enterprise support
  # you MUST get your configuration and run books reviewed by Camunda before going to production.
  # This is necessary for us to be able to help you in case of outages,
  # due to the complexity of operating multi-region setups and the dependencies to the underlying Kubernetes prerequisites.
  # If you operate this in the wrong way you risk corruption and complete loss of all data especially in the dual-region case.
  # If you can, consider three regions. Please, contact your customer success manager as soon as you start planning a multi-region setup.
  # Camunda reserves the right to limit support if no review was done prior to launch or the review showed significant risks.
  multiregion:
    # number of regions that this Camunda Platform instance is stretched across
    regions: 2
  identity:
    auth:
      # Disable the Identity authentication
      # it will fall back to basic-auth: demo/demo as default user
      enabled: false
  elasticsearch:
    disableExporter: true

operate:
  env:
  - name: CAMUNDA_OPERATE_BACKUP_REPOSITORYNAME
    value: "camunda_backup"
tasklist:
  env:
  - name: CAMUNDA_TASKLIST_BACKUP_REPOSITORYNAME
    value: "camunda_backup"

identity:
  enabled: false

# Temporary Helm chart v10 fix
identityKeycloak:
  enabled: false

optimize:
  enabled: false

connectors:
  enabled: false

zeebe:
  clusterSize: 2
  partitionCount: 2
  replicationFactor: 1
  pvcSize: 1Gi

  readinessProbe:
    enabled: false # todo: revert
    scheme: HTTPS
  livenessProbe:
    enabled: false # todo: revert

    scheme: HTTPS
  resources:
    requests:
      cpu: "100m"
      memory: "512M"
    limits:
      cpu: "512m"
      memory: "2Gi"

zeebe-gateway:
  replicas: 1
  resources:
    requests:
      cpu: "100m"
      memory: "512M"
    limits:
      cpu: "1000m"
      memory: "1Gi"

  logLevel: ERROR

elasticsearch:
  enabled: true
  master:
    replicaCount: 2
    resources:
      requests:
        cpu: "100m"
        memory: "512M"
      limits:
        cpu: "1000m"
        memory: "2Gi"
    persistence:
      size: 15Gi
  initScripts:
    init-keystore.sh: |
      #!/bin/bash
      set -e

      echo "Adding S3 access keys to Elasticsearch keystore..."

      # Add S3 client camunda keys to the keystore
      echo "${DOLLAR}S3_SECRET_KEY" | elasticsearch-keystore add -x s3.client.camunda.secret_key
      echo "${DOLLAR}S3_ACCESS_KEY" | elasticsearch-keystore add -x s3.client.camunda.access_key
  extraEnvVarsSecret: elasticsearch-env-secret
  # Bitnami chart fix to allow adding keystore secrets
  extraVolumeMounts:
  - name: empty-dir
    mountPath: /bitnami/elasticsearch
    subPath: app-volume-dir
# yamllint disable-line rule:comments-indentation
  # Fix addition for Helm Chart < 10
  # extraVolumes:
  # - name: empty-dir
  #   emptyDir: {}
