#!/bin/bash

case "$1" in
setup)
    terraform apply -auto-approve
    terraform output -raw simple_cluster > simple_cluster.conf
    terraform output -raw ha_cluster > ha_cluster.conf

    KUBECONFIG=$(pwd)/simple_cluster.conf kubectl apply -f manifest.yaml
    KUBECONFIG=$(pwd)/ha_cluster.conf kubectl apply -f manifest.yaml

    KUBECONFIG=$(pwd)/simple_cluster.conf kubectl wait deployment/nginx --for condition=available
    KUBECONFIG=$(pwd)/ha_cluster.conf kubectl wait deployment/nginx --for condition=available
    ;;
teardown)
    # Try to delete the load-balancers first, as they will not be to deleted otherwise. Do not fail if
    # it fails, otherwise 
    KUBECONFIG=$(pwd)/simple_cluster.conf kubectl delete -f manifest.yaml || true
    KUBECONFIG=$(pwd)/ha_cluster.conf kubectl delete -f manifest.yaml || true
    
    # Disable locking in case `terraform apply` was interrupted
    terraform destroy -auto-approve -lock=false
    ;;
esac
