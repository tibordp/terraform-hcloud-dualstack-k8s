#!/bin/bash
set -euo pipefail

# Install ip-masq-agent
kubectl apply -f ip-masq-agent.yaml

# Install cloud provider
kubectl -n kube-system create secret generic hcloud --from-literal=token="$HCLOUD_TOKEN"
kubectl apply -f https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/latest/download/ccm.yaml

# Install storage provider
kubectl -n kube-system create secret generic hcloud-csi --from-literal=token="$HCLOUD_TOKEN"
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/v1.5.3/deploy/kubernetes/hcloud-csi.yml
