#!/bin/bash
set -euo pipefail

if [ -z "$HCLOUD_TOKEN" ]
then
    echo "\$HCLOUD_TOKEN is empty"
    exit 1
fi

# Install CNI
curl -LO https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin

cilium install --version v1.10.0-rc1 \
  --ipam kubernetes \
  --config enable-ipv6=true,enable-ipv6-masquerade=false,egress-masquerade-interfaces=eth0,ipam=kubernetes

# Install cloud provider
kubectl -n kube-system create secret generic hcloud --from-literal=token="$HCLOUD_TOKEN"
kubectl apply -f https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/latest/download/ccm.yaml

# Install storage provider
kubectl -n kube-system create secret generic hcloud-csi --from-literal=token="$HCLOUD_TOKEN"
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/v1.5.3/deploy/kubernetes/hcloud-csi.yml