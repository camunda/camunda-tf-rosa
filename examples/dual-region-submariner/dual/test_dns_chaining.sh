#!/bin/bash

set -e

create_namespace() {
    local context=$1
    local namespace=$2
    if kubectl --context "$context" get namespace "$namespace" &> /dev/null; then
        echo "Namespace $namespace already exists."
    else
        # Create the namespace
        kubectl --context "$context" create namespace "$namespace"
    fi
}

ping_instance() {
    local context=$1
    local source_namespace=$2
    local target_namespace=$3
    local cluster_name=$4
    for ((i=1; i<=5; i++))
    do
        echo "Iteration $i - $source_namespace -> $target_namespace"
        command_test="kubectl --context \"$context\" exec -n default -it ubuntu-with-nmap -- curl \"http://sample-nginx.$cluster_name.sample-nginx-peer.$target_namespace.svc.clusterset.local:8080\""
        echo "Running command: $command_test"
        output=$(eval "$command_test")
        echo "Output: $output"
        if output=$(echo "$output" | grep "sample-nginx"); then
            echo "Success: $output"
            return
        else
            echo "Try again in 15 seconds..."
            sleep 15
        fi
    done
    echo "Failed to reach the target instance - CoreDNS might not be reloaded yet or wrongly configured"
}

create_namespace "$CLUSTER_0" "$CAMUNDA_NAMESPACE_0"
create_namespace "$CLUSTER_1" "$CAMUNDA_NAMESPACE_0"
create_namespace "$CLUSTER_1" "$CAMUNDA_NAMESPACE_1"
create_namespace "$CLUSTER_1" "$CAMUNDA_NAMESPACE_0"

kubectl --context "$CLUSTER_0" apply -f nginx-submariner.yaml -n "$CAMUNDA_NAMESPACE_0"
kubectl --context "$CLUSTER_1" apply -f nginx-submariner.yaml -n "$CAMUNDA_NAMESPACE_1"

kubectl --context "$CLUSTER_0" wait --for=condition=Ready pod/sample-nginx -n "$CAMUNDA_NAMESPACE_0" --timeout=300s
kubectl --context "$CLUSTER_1" wait --for=condition=Ready pod/sample-nginx -n "$CAMUNDA_NAMESPACE_1" --timeout=300s

kubectl --context "$CLUSTER_0" -n "$CAMUNDA_NAMESPACE_0" describe serviceexport
kubectl --context "$CLUSTER_1" -n "$CAMUNDA_NAMESPACE_1" describe serviceexport

kubectl --context "$CLUSTER_0" -n "$CAMUNDA_NAMESPACE_0" describe serviceimport
kubectl --context "$CLUSTER_1" -n "$CAMUNDA_NAMESPACE_1" describe serviceimport

kubectl --context "$CLUSTER_0"  apply -f debug.yml
kubectl --context "$CLUSTER_1"  apply -f debug.yml

kubectl --context "$CLUSTER_0" wait --for=condition=Ready pod/ubuntu-with-nmap -n "default" --timeout=300s
kubectl --context "$CLUSTER_1" wait --for=condition=Ready pod/ubuntu-with-nmap -n "default" --timeout=300s

echo "Sleeping 10s"
sleep 10

ping_instance "$CLUSTER_0" "$CAMUNDA_NAMESPACE_0" "$CAMUNDA_NAMESPACE_1" "$CLUSTER_1"
ping_instance "$CLUSTER_1" "$CAMUNDA_NAMESPACE_1" "$CAMUNDA_NAMESPACE_0" local-cluster

echo "Cleaning up pods..."

kubectl --context "$CLUSTER_0"  delete -f debug.yml
kubectl --context "$CLUSTER_1"  delete -f debug.yml

kubectl --context "$CLUSTER_0" delete -f nginx-submariner.yaml -n "$CAMUNDA_NAMESPACE_0"
kubectl --context "$CLUSTER_1" delete -f nginx-submariner.yaml -n "$CAMUNDA_NAMESPACE_1"
