import subprocess
import json
import os

def get_namespace_input(prompt):
    ns = input(prompt)
    while not ns:
        ns = input(prompt)
    return ns

def get_host_ips(context, region, host):
    try:
        # Get the hostname
        hostname_cmd = [
            "kubectl", "--context", context, "-n", "openshift-dns",
            "get", "svc", "dns-default-lb", "-o",
            "jsonpath={.status.loadBalancer.ingress[0].hostname}"
        ]
        hostname = subprocess.check_output(hostname_cmd).decode('utf-8').strip()
        host = hostname.split('-')[0]

        # Get the IPs
        ip_cmd = [
            "aws", "ec2", "describe-network-interfaces", "--region", region,
            "--filters", f"Name=description,Values=ELB net/{host}*",
            "--query", "NetworkInterfaces[*].PrivateIpAddress", "--output", "json", "--no-cli-pager"
        ]
        ip_output = subprocess.check_output(ip_cmd).decode('utf-8')
        ips = json.loads(ip_output)
        return ips
    except subprocess.CalledProcessError as e:
        print(f"Error retrieving host IPs: {e}")
        return []

def generate_yaml(ns, ns_f, ips):
    yaml = f"""
  - name: {ns}
    zones:
    - {ns}.svc.cluster.local
    forwardPlugin:
      policy: Random
      upstreams:"""

    for ip in ips:
        yaml += f"""
      - {ip}:53"""

    yaml += f"""
  - name: {ns_f}
    zones:
    - {ns_f}.svc.cluster.local
    forwardPlugin:
      policy: Random
      upstreams:"""

    for ip in ips:
        yaml += f"""
      - {ip}:53"""

    return yaml.strip()

def main():
    # Get namespaces from environment variables
    namespace_0 = os.getenv("CAMUNDA_NAMESPACE_0", "")
    namespace_0_failover = os.getenv("CAMUNDA_NAMESPACE_0_FAILOVER", "")
    namespace_1 = os.getenv("CAMUNDA_NAMESPACE_1", "")
    namespace_1_failover = os.getenv("CAMUNDA_NAMESPACE_1_FAILOVER", "")

    if any(ns == "" for ns in [namespace_0, namespace_0_failover, namespace_1, namespace_1_failover]):
        namespace_0 = get_namespace_input("Enter the Kubernetes cluster namespace where Camunda 8 is installed, in region 0: ")
        namespace_0_failover = get_namespace_input("Enter the failover Kubernetes cluster namespace where Camunda 8 is installed, in region 0: ")
        namespace_1 = get_namespace_input("Enter the Kubernetes cluster namespace where Camunda 8 is installed, in region 1: ")
        namespace_1_failover = get_namespace_input("Enter the failover Kubernetes cluster namespace where Camunda 8 is installed, in region 1: ")

    if any(ns == "" for ns in [namespace_0, namespace_0_failover, namespace_1, namespace_1_failover]):
        print("Namespaces cannot be empty")
        return

    if len(set([namespace_0, namespace_0_failover, namespace_1, namespace_1_failover])) < 4:
        print("Kubernetes namespaces for Camunda installations must be called differently")
        return

    # Get internal load balancer IPs
    context_0 = os.getenv("CLUSTER_0")
    context_1 = os.getenv("CLUSTER_1")
    region_0 = os.getenv("REGION_0")
    region_1 = os.getenv("REGION_1")

    if not all([context_0, context_1, region_0, region_1]):
        print("Missing environment variables. Please make sure CLUSTER_0, CLUSTER_1, REGION_0, and REGION_1 are set.")
        return

    print("Retrieving internal lb 0 ips")
    internal_lb_0 = get_host_ips(context_0, region_0, namespace_0)
    print("Retrieving internal lb 1 ips")
    internal_lb_1 = get_host_ips(context_1, region_1, namespace_1)

    if not internal_lb_0 or not internal_lb_1:
        print(f"Could not retrieve the internal load balancer IPs. Please try again. internal_lb_0={internal_lb_0}, internal_lb_1={internal_lb_1}")
        return

    config_for_cluster_0 = generate_yaml(namespace_1, namespace_1_failover, internal_lb_1)
    config_for_cluster_1 = generate_yaml(namespace_0, namespace_0_failover, internal_lb_0)

    print(f"""
Please copy the following between
### Cluster 0 - Start ### and ### Cluster 0 - End ###
and insert it at the end of your dns-default configmap in Cluster 0

oc --context {context_0} edit dns.operator/default

### Cluster 0 - Start ###
spec:
  servers:
  {config_for_cluster_0}
### Cluster 0 - End ###

Please copy the following between
### Cluster 1 - Start ### and ### Cluster 1 - End ###
and insert it at the end of your dns-default configmap in Cluster 1

oc --context {context_1} edit dns.operator/default

### Cluster 1 - Start ###
spec:
  servers:
  {config_for_cluster_1}
### Cluster 1 - End ###
""")

if __name__ == "__main__":
    main()
