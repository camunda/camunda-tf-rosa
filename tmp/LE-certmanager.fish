 # This file documents the setup of Let'sEncrypt issuer on Cert-Manager for ROSA

# Now we need to generate public the certificates, we will deploy cert-manager to do it
# based on https://cloud.redhat.com/experts/rosa/dynamic-certificates/



# Configure AWS IAM Policy
set -x AWS_ACCOUNT_ID (aws sts get-caller-identity --query Account --output text)
set -x OIDC_PROVIDER_CLUSTER_0 (oc --context $CLUSTER_0 get authentication.config.openshift.io cluster -o json | jq -r .spec.serviceAccountIssuer| sed -e "s/^https:\/\///")
set -x OIDC_PROVIDER_CLUSTER_1 (oc --context $CLUSTER_1 get authentication.config.openshift.io cluster -o json | jq -r .spec.serviceAccountIssuer| sed -e "s/^https:\/\///")

aws iam create-policy --policy-name "$CLUSTER_0-cert-manager-r53-policy" --policy-document file://./cert-manager/cert-manager-r53-policy.json --query 'Policy.Arn' --output text
set -x POLICY_CLUSTER_0 (aws iam list-policies | jq -r ".Policies[] | select(.PolicyName == \"$CLUSTER_0-cert-manager-r53-policy\") | .Arn")
echo "$POLICY_CLUSTER_0"

aws iam create-policy --policy-name "$CLUSTER_1-cert-manager-r53-policy" --policy-document file://./cert-manager/cert-manager-r53-policy.json --query 'Policy.Arn' --output text
set -x POLICY_CLUSTER_1 (aws iam list-policies | jq -r ".Policies[] | select(.PolicyName == \"$CLUSTER_1-cert-manager-r53-policy\") | .Arn")
echo "$POLICY_CLUSTER_1"

# create the TrustPolicy for each cluster
OIDC_PROVIDER=$OIDC_PROVIDER_CLUSTER_0 envsubst < ./cert-manager/TrustPolicy.json.tpl > "./cert-manager/TrustPolicy-$CLUSTER_0.json"
aws iam create-role --role-name "$CLUSTER_0-cert-manager-operator" --assume-role-policy-document file://./cert-manager/TrustPolicy-$CLUSTER_0.json --query "Role.Arn" --output text
set -x ROLE_CLUSTER_0 (aws iam list-roles | jq -r ".Roles[] | select(.RoleName == \"$CLUSTER_0-cert-manager-operator\") | .Arn")

OIDC_PROVIDER=$OIDC_PROVIDER_CLUSTER_1 envsubst < ./cert-manager/TrustPolicy.json.tpl > "./cert-manager/TrustPolicy-$CLUSTER_1.json"
aws iam create-role --role-name "$CLUSTER_1-cert-manager-operator" --assume-role-policy-document file://./cert-manager/TrustPolicy-$CLUSTER_1.json --query "Role.Arn" --output text
set -x ROLE_CLUSTER_1 (aws iam list-roles | jq -r ".Roles[] | select(.RoleName == \"$CLUSTER_1-cert-manager-operator\") | .Arn")

# attach the policy to the role
aws iam attach-role-policy --role-name "$CLUSTER_0-cert-manager-operator" --policy-arn "$POLICY_CLUSTER_0"
aws iam attach-role-policy --role-name "$CLUSTER_1-cert-manager-operator" --policy-arn "$POLICY_CLUSTER_1"

# Now we use the AWS IAM Role to allow cert-manager to perform DNS records to perform ACME challenge resolution (DNS-01)
kubectl --context "$CLUSTER_0" annotate serviceaccount cert-manager -n cert-manager "eks.amazonaws.com/role-arn=$ROLE_CLUSTER_0"
kubectl --context "$CLUSTER_1" annotate serviceaccount cert-manager -n cert-manager "eks.amazonaws.com/role-arn=$ROLE_CLUSTER_1"

# tell cert-manager to use public resolvers
oc --context "$CLUSTER_0" patch certmanager cluster --type='json' -p='[
      {"op":"add","path":"/spec/controllerConfig","value":{"overrideArgs":["--dns01-recursive-nameservers=1.1.1.1:53,1.0.0.1:53","--dns01-recursive-nameservers-only"]}}
    ]'
oc --context "$CLUSTER_1" patch certmanager cluster --type='json' -p='[
      {"op":"add","path":"/spec/controllerConfig","value":{"overrideArgs":["--dns01-recursive-nameservers=1.1.1.1:53,1.0.0.1:53","--dns01-recursive-nameservers-only"]}}
    ]'

# restart
kubectl --context "$CLUSTER_0" delete pod -n cert-manager -l app=cert-manager
kubectl --context "$CLUSTER_1" delete pod -n cert-manager -l app=cert-manager



# Create a ClusterIssuer
set -x HOSTED_ZONE_ID_CLUSTER_0 (aws route53 list-hosted-zones | jq -r ".HostedZones[] | select(.Name == "\""$CLUSTER_0_DOMAIN."\"" and .Config.PrivateZone == false) | .Id" | sed 's/\/hostedzone\///')
set -x HOSTED_ZONE_ID_CLUSTER_1 (aws route53 list-hosted-zones | jq -r ".HostedZones[] | select(.Name == "\""$CLUSTER_1_DOMAIN."\"" and .Config.PrivateZone == false) | .Id" | sed 's/\/hostedzone\///')

set -x LETSENCRYPT_EMAIL youremail@work.com
HOSTED_ZONE_ID="$HOSTED_ZONE_ID_CLUSTER_0" HOSTED_ZONE_REGION="$REGION_0" envsubst < ./cert-manager/cluster-issuer.yml.tpl | kubectl --context $CLUSTER_0 apply -f -
HOSTED_ZONE_ID="$HOSTED_ZONE_ID_CLUSTER_1" HOSTED_ZONE_REGION="$REGION_1" envsubst < ./cert-manager/cluster-issuer.yml.tpl | kubectl --context $CLUSTER_1 apply -f -

# wait until the cluster issuer is ready
kubectl --context $CLUSTER_0 describe clusterissuer letsencryptissuer
kubectl --context $CLUSTER_1 describe clusterissuer letsencryptissuer

# we can now generate a certificate for the custom domain of zeebe
# /!\ this can take several minutes
CLUSTER_ZEEBE_CN_FORWARDER_DOMAIN="$CLUSTER_0_ZEEBE_INGRESS_CONTROLLER_DOMAIN_WILDCARD" \
CLUSTER_ZEEBE_FORWARDER_DOMAIN="$CLUSTER_0_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" \
envsubst < zeebe-cert.yml.tpl | kubectl --context $CLUSTER_0 --namespace "$CAMUNDA_NAMESPACE_0" apply -f -

CLUSTER_ZEEBE_CN_FORWARDER_DOMAIN="$CLUSTER_1_ZEEBE_INGRESS_CONTROLLER_DOMAIN_WILDCARD" \
CLUSTER_ZEEBE_FORWARDER_DOMAIN="$CLUSTER_1_ZEEBE_PTP_INGRESS_WILDCARD_DOMAIN" \
envsubst < zeebe-cert.yml.tpl | kubectl --context $CLUSTER_1 --namespace "$CAMUNDA_NAMESPACE_1" apply -f -

# wait until the certificate is ready
kubectl --context "$CLUSTER_0" --namespace "$CAMUNDA_NAMESPACE_0" get certificate.cert-manager.io/zeebe-tls-cert --watch
kubectl --context "$CLUSTER_1" --namespace "$CAMUNDA_NAMESPACE_1" get certificate.cert-manager.io/zeebe-tls-cert --watch
