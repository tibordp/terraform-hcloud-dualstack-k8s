#!/bin/bash
set -euo pipefail

setup_cluster() {
    # Wait for cluster addons to become available
    ./kubectl --kubeconfig "$1" wait --timeout=240s --for condition=ready $(./kubectl --kubeconfig "$1" get nodes -o name)
    ./kubectl --kubeconfig "$1" wait --timeout=240s --for condition=available -n kube-system deployment/coredns 

    # Install our workload
    ./kubectl --kubeconfig "$1" apply -f manifest.yaml
    ./kubectl --kubeconfig "$1" wait --timeout=240s --for condition=available deployment/nginx 
}

teardown_cluster() {
    ./kubectl --kubeconfig "$1" delete -f manifest.yaml
}

case "$1" in
kubectl)
    curl -LO https://dl.k8s.io/release/v1.22.2/bin/linux/amd64/kubectl
    chmod +x kubectl
    ;;
setup)
    terraform apply -auto-approve
    terraform output -no-color -raw simple_cluster > simple_cluster.conf
    terraform output -no-color -raw ha_cluster > ha_cluster.conf

    setup_cluster "$(pwd)/simple_cluster.conf"
    setup_cluster "$(pwd)/ha_cluster.conf"
    ;;
teardown)
    # Try to delete the load-balancers first, as they will not be to deleted otherwise. Do not fail if
    # it fails, otherwise 
    teardown_cluster "$(pwd)/simple_cluster.conf" || true
    teardown_cluster "$(pwd)/ha_cluster.conf" || true
    
    # Disable locking in case `terraform apply` was interrupted
    terraform destroy -auto-approve -lock=false
    ;;
*)
    exit 1
    ;;
esac
