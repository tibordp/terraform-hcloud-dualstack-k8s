#!/bin/bash
set -euo pipefail

# Install network plugin
kubectl apply -f wigglenet.yaml

# Install cloud provider
kubectl -n kube-system create secret generic hcloud \
    --from-literal=token="$HCLOUD_TOKEN" \
    -o yaml --dry-run=client | kubectl apply -f-
kubectl apply -f hetzner_ccm.yaml

# Install storage provider
kubectl -n kube-system create secret generic hcloud-csi \
    --from-literal=token="$HCLOUD_TOKEN"  \
    -o yaml --dry-run=client | kubectl apply -f-
kubectl apply -f hetzner_csi.yaml
