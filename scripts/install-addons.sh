#!/bin/bash
set -euo pipefail

# Install network plugin
kubectl apply -f wigglenet.yaml

# Install cloud provider
if [[ -z "${HCLOUD_NETWORK}" ]]; then
    kubectl -n kube-system create secret generic hcloud \
        --from-literal=token="$HCLOUD_TOKEN" \
        -o yaml --dry-run=client | kubectl apply -f-
else
    kubectl -n kube-system create secret generic hcloud \
        --from-literal=token="$HCLOUD_TOKEN" \
        --from-literal=network="$HCLOUD_NETWORK" \
        -o yaml --dry-run=client | kubectl apply -f-
fi

kubectl apply -f hetzner_ccm.yaml
kubectl apply -f hetzner_csi.yaml
