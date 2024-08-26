# Based on https://rcarrata.com/rosa/rosa-submariner/ + https://docs.redhat.com/en/documentation/red_hat_advanced_cluster_management_for_kubernetes/2.2/html/manage_cluster/submariner#submariner

# I. Deploy RHACM Cluster Hub

kubectl --context $CLUSTER_0 apply -f submariner/acm-ns.yml
kubectl --context $CLUSTER_0 apply -f submariner/operatorgroup.yml
kubectl --context $CLUSTER_0 apply -f submariner/acm-sub.yml

# Verify the installation
# wait until it's "Ready"
kubectl --context $CLUSTER_0 --namespace open-cluster-management get csv --watch

# Install MultiClusterHub
kubectl --context $CLUSTER_0 apply -f submariner/multi-cluster-hub.yml
# wait until it's "Running", can take up to 10 minutes
kubectl --context $CLUSTER_0 get mch -n open-cluster-management multiclusterhub --watch

## II. Deploy Submariner

# Create submariner machine pools (this is required by https://github.com/submariner-io/submariner/issues/1896)
# (TODO: this could be integrated directly in the tf module

rosa create machinepool --cluster $CLUSTER_0 --name=sm-gw-mp --replicas=2 --labels='submariner.io/gateway=true' # todo: ideally, deploy accross regions
rosa list machinepools -c $CLUSTER_0


rosa create machinepool --cluster $CLUSTER_1 --name=sm-gw-mp --replicas=2 --labels='submariner.io/gateway=true'
rosa list machinepools -c $CLUSTER_1

# wait for nodes to be ready
kubectl --context $CLUSTER_0 get nodes --show-labels | grep submariner
kubectl --context $CLUSTER_1 get nodes --show-labels | grep submariner

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

# NAME            HUB ACCEPTED   MANAGED CLUSTER URLS                                 JOINED   AVAILABLE   AGE
# cl-oc-1b        true           https://api.cl-oc-1b.f70c.p3.openshiftapps.com:443   True     True        6m13s
# cl-oc-2         true           https://api.cl-oc-2.5egh.p3.openshiftapps.com:443    True     True        50s
# local-cluster   true           https://api.cl-oc-1b.f70c.p3.openshiftapps.com:443   True     True        36m
