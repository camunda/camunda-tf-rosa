# Based on https://rcarrata.com/rosa/rosa-submariner/ + https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.2/html/manage_cluster/submariner#submariner
# https://github.com/stolostron/deploy/blob/master/README.md
# https://meatybytes.io/posts/openshift/ocp-features/multi-cluster/connectivity/

# If uninstall fails: https://access.redhat.com/solutions/6975868

# I. Deploy RHACM Cluster Hub (TODO: this chapter is bugged and doing it via the UI works)

kubectl --context $CLUSTER_0 apply -f submariner/acm-ns.yml
kubectl --context $CLUSTER_0 apply -f submariner/operatorgroup.yml
kubectl --context $CLUSTER_0 apply -f submariner/acm-sub.yml

# Verify the installation
# wait until it's "Succeeded"
kubectl --context $CLUSTER_0 --namespace open-cluster-management get csv --watch

# Install MultiClusterHub
kubectl --context $CLUSTER_0 apply -f submariner/multi-cluster-hub.yml
# wait until it's "Running", can take up to 10 minutes
kubectl --context $CLUSTER_0 get mch -n open-cluster-management multiclusterhub --watch

## II. Prepare Cluster Hub for Submariner

# Create submariner machine pools (this is required by https://github.com/submariner-io/submariner/issues/1896)
# (TODO: this could be integrated directly in the tf module

rosa create machinepool --cluster $CLUSTER_0 --name=sm-gw-mp --replicas=2 --labels='submariner.io/gateway=true' # todo: ideally, deploy accross regions
rosa list machinepools -c $CLUSTER_0


rosa create machinepool --cluster $CLUSTER_1 --name=sm-gw-mp --replicas=2 --labels='submariner.io/gateway=true'
rosa list machinepools -c $CLUSTER_1

# wait for nodes to be ready
kubectl --context $CLUSTER_0 get nodes --show-labels --watch | grep submariner
kubectl --context $CLUSTER_1 get nodes --show-labels --watch | grep submariner

# Create the ManagedClusterSet in the Cluster0
kubectl --context $CLUSTER_0 get mch -A
kubectl --context $CLUSTER_0  apply -f submariner/managed-cluster-set.yml

# Import Cluster 0
set -x SUB0_TOKEN (oc --context "$CLUSTER_0" whoami -t)
echo $SUB0_TOKEN

CLUSTER_NAME="$CLUSTER_0" envsubst < submariner/managed-cluster.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_0" CLUSTER_TOKEN="$SUB0_TOKEN" CLUSTER_API="$CLUSTER_0_API_URL" envsubst < submariner/auto-import-cluster-secret.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_0" envsubst < submariner/klusterlet-config.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -

# List Managed Cluster sets
kubectl --context "$CLUSTER_0" get managedclusters "$CLUSTER_0"


# Import Cluster 1
set -x SUB1_TOKEN (oc --context "$CLUSTER_1" whoami -t)
echo $SUB1_TOKEN

CLUSTER_NAME="$CLUSTER_1" envsubst < submariner/managed-cluster.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_1" CLUSTER_TOKEN="$SUB1_TOKEN" CLUSTER_API="$CLUSTER_1_API_URL" envsubst < submariner/auto-import-cluster-secret.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -
CLUSTER_NAME="$CLUSTER_1" envsubst < submariner/klusterlet-config.yml.tpl | kubectl --context "$CLUSTER_0" apply -f -


kubectl --context "$CLUSTER_0" get managedclusters

# edit local cluster
# cluster.open-cluster-management.io/clusterset=rosa-clusters

# NAME            HUB ACCEPTED   MANAGED CLUSTER URLS                                 JOINED   AVAILABLE   AGE
# cl-oc-1b        true           https://api.cl-oc-1b.f70c.p3.openshiftapps.com:443   True     True        6m13s
# cl-oc-2         true           https://api.cl-oc-2.5egh.p3.openshiftapps.com:443    True     True        50s
# local-cluster   true           https://api.cl-oc-1b.f70c.p3.openshiftapps.com:443   True     True        36m

# III. Deploy Submariner addon

# TODO: use manifests for this part
# Deploy Submariner Addon in Managed ROSA clusters from the RHACM UI
#     Inside of the ClusterSets tab, go to the rosa-aro-clusters generated.
#     Go to Submariner add-ons and Click in “Install Submariner Add-Ons”
#     Configure the Submariner addons adding both ROSA clusters generated:

# Check readiness

# IV. Deploy the app
cd acm-demo-app/

kubectl --context "$CLUSTER_0"  apply -f acm-demo-app/guestbook-app/guestbook/namespace.yaml
kubectl --context "$CLUSTER_1"  apply -f acm-demo-app/redis-secondary-app/redis-secondary/namespace.yaml

kubectl --context "$CLUSTER_0" apply -f acm-demo-app/guestbook-app/guestbook/
kubectl --context "$CLUSTER_0" apply -f acm-demo-app/redis-primary-app/redis-primary

kubectl --context "$CLUSTER_1" apply -f acm-demo-app/redis-secondary-app/redis-secondary

# relax some SCCs
oc --context "$CLUSTER_0" adm policy add-scc-to-user anyuid -z default -n guestbook
oc --context "$CLUSTER_0" delete pod --all -n guestbook

oc --context "$CLUSTER_1" adm policy add-scc-to-user anyuid -z default -n guestbook
oc --context "$CLUSTER_1" delete pod --all -n guestbook

# get the route
kubectl --context "$CLUSTER_0" -n guestbook get routes

# continue with https://submariner.io/getting-started/architecture/service-discovery/
