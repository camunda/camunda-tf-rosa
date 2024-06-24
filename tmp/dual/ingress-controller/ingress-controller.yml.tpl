apiVersion: operator.openshift.io/v1
kind: IngressController
metadata:
  annotations:
    ingress.operator.openshift.io/auto-delete-load-balancer: "true"
    ingress.operator.openshift.io/default-enable-http2: "true" # required for grpc
  finalizers:
  - ingresscontroller.operator.openshift.io/finalizer-ingresscontroller
  generation: 2
  labels:
    hypershift.openshift.io/managed: "true"
  name: "zeebe-ingress"
  namespace: openshift-ingress-operator
spec:
  clientTLS:
    clientCA:
      name: ""
    clientCertificatePolicy: ""
  domain: $DOMAIN
  endpointPublishingStrategy:
    loadBalancer:
      dnsManagementPolicy: Unmanaged
      providerParameters:
        aws:
          networkLoadBalancer: {}
          type: NLB
        type: AWS
      scope: "External"
    type: LoadBalancerService
  httpCompression: {}
  httpEmptyRequestsPolicy: Respond
  httpErrorCodePages:
    name: ""
  replicas: 2
  tuningOptions:
    reloadInterval: 0s
  unsupportedConfigOverrides: null
  routeAdmission:
    wildcardPolicy: "WildcardsAllowed"
