import sys
import os

def generate_initial_contact(cluster_0, namespace_0, cluster_1, namespace_1, release, count, port_number=26502):
    result = []
    for i in range(count // 2):
        result.append(f"{release}-zeebe-{i}.{cluster_0}.{release}-zeebe.{namespace_0}.svc.clusterset.local:{port_number}")
        result.append(f"{release}-zeebe-{i}.{cluster_1}.{release}-zeebe.{namespace_1}.svc.clusterset.local:{port_number}")
    return ",".join(result)

def generate_exporter_elasticsearch_url(namespace, release, port_number=9200):
    return f"http://{release}-elasticsearch-master-hl.{namespace}.svc.clusterset.local:{port_number}"

def main():
    # Read environment variables
    cluster_0 = "local-cluster"
    cluster_1 = os.getenv('CLUSTER_1', '')

    namespace_0 = os.getenv('CAMUNDA_NAMESPACE_0', '')
    namespace_1 = os.getenv('CAMUNDA_NAMESPACE_1', '')

    namespace_0_failover = os.getenv('CAMUNDA_NAMESPACE_0_FAILOVER', '')
    namespace_1_failover = os.getenv('CAMUNDA_NAMESPACE_1_FAILOVER', '')

    helm_release_name = os.getenv('HELM_RELEASE_NAME', '')

    mode = "normal"
    target_text = "in the base Camunda Helm chart values file 'camunda-values.yml'"

    if len(sys.argv) > 1:
        mode = sys.argv[1].lower()
        if mode == "failover":
            print("Failover mode is enabled. The script will generate required values for failover.")
            target_text = f"in the failover Camunda Helm chart values file '{os.getenv('REGION_SURVIVING', '')}/camunda-values-failover.yml' and in the base Camunda Helm chart values file 'camunda-values.yml'"
        elif mode == "failback":
            print("Failback mode is enabled. The script will generate required values for failback.")
            target_text = f"in the failover Camunda Helm chart values file '{os.getenv('REGION_SURVIVING', '')}/camunda-values-failover.yml' and in the base Camunda Helm chart values file 'camunda-values.yml'"

    # Taking inputs from the user
    if not namespace_0:
        namespace_0 = input("Enter the Kubernetes cluster namespace where Camunda 8 is installed, in region 0: ")
    if not namespace_1:
        namespace_1 = input("Enter the Kubernetes cluster namespace where Camunda 8 is installed, in region 1: ")
    if not cluster_1:
        cluster_1 = input("Enter the Kubernetes cluster name where Camunda 8 is installed, in region 1: ")

    if mode == "failover":
        if not namespace_0_failover:
            namespace_0_failover = input("Enter the Kubernetes cluster namespace where Camunda 8 should be installed, in region 0 for failover mode: ")
        if not namespace_1_failover:
            namespace_1_failover = input("Enter the Kubernetes cluster namespace where Camunda 8 should be installed, in region 1 for failover mode: ")
    if not helm_release_name:
        helm_release_name = input("Enter Helm release name used for installing Camunda 8 in both Kubernetes clusters: ")

    if mode == "failover":
        lost_region = input("Enter the region that was lost, values can either be 0 or 1: ")
        if lost_region not in ['0', '1']:
            print(f"Invalid region {lost_region} provided for the lost region. Please provide either 0 or 1 as input value.")
            sys.exit(1)

    cluster_size = int(input("Enter Zeebe cluster size (total number of Zeebe brokers in both Kubernetes clusters): "))

    if cluster_size % 2 != 0:
        print(f"Cluster size {cluster_size} is an odd number and not supported in a multi-region setup (must be an even number)")
        sys.exit(1)

    if cluster_size < 4:
        print(f"Cluster size {cluster_size} is too small and should be at least 4. A multi-region setup is not recommended for a small cluster size.")
        sys.exit(1)

    if namespace_0 == namespace_1:
        print("Kubernetes namespaces for Camunda installations must be called differently")
        sys.exit(1)

    # Generate URLs
    initial_contact = generate_initial_contact(cluster_0, namespace_0, cluster_1, namespace_1, helm_release_name, cluster_size)
    elastic0 = generate_exporter_elasticsearch_url(namespace_0, helm_release_name)
    elastic1 = generate_exporter_elasticsearch_url(namespace_1, helm_release_name)

    if mode == "failover":
        if lost_region == '0':
            elastic0 = generate_exporter_elasticsearch_url(namespace_1_failover, helm_release_name)
            elastic1 = generate_exporter_elasticsearch_url(namespace_1, helm_release_name)
        else:
            elastic0 = generate_exporter_elasticsearch_url(namespace_0, helm_release_name)
            elastic1 = generate_exporter_elasticsearch_url(namespace_0_failover, helm_release_name)

    # Output results
    print("\nPlease use the following to change the existing environment variable ZEEBE_BROKER_CLUSTER_INITIALCONTACTPOINTS {}. It's part of the 'zeebe.env' path.".format(target_text))
    print("- name: ZEEBE_BROKER_CLUSTER_INITIALCONTACTPOINTS")
    print(f"  value: {initial_contact}")

    print("\nPlease use the following to change the existing environment variable ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION0_ARGS_URL {}. It's part of the 'zeebe.env' path.".format(target_text))
    print("- name: ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION0_ARGS_URL")
    print(f"  value: {elastic0}")

    print("\nPlease use the following to change the existing environment variable ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION1_ARGS_URL {}. It's part of the 'zeebe.env' path.".format(target_text))
    print("- name: ZEEBE_BROKER_EXPORTERS_ELASTICSEARCHREGION1_ARGS_URL")
    print(f"  value: {elastic1}")

if __name__ == "__main__":
    main()
