#!/bin/bash
set -euo pipefail

# Install network plugin
kubectl apply -f wigglenet.yaml

# Install cloud provider
kubectl -n kube-system create secret generic hcloud \
    --from-literal=token="$HCLOUD_TOKEN" \
    -o yaml --dry-run=client | kubectl apply -f-
kubectl apply -f https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/latest/download/ccm.yaml

# Install storage provider
kubectl -n kube-system create secret generic hcloud-csi \
    --from-literal=token="$HCLOUD_TOKEN"  \
    -o yaml --dry-run=client | kubectl apply -f-
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/v1.5.3/deploy/kubernetes/hcloud-csi.yml
