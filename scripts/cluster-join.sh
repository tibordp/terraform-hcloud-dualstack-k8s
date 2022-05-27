#!/bin/bash
set -euo pipefail

if [[ -f "$HOME/.kube/config" ]]; then
    # This script runs also on the node that bootstrapped the cluster
    # so that it can be replaced later.
    echo "Node already provisioned, skipping..."
    exit 0
fi

if [[ -f "join-command.sh" ]]; then
  chmod +x join-command.sh
  ./join-command.sh
else
  kubeadm init --config cluster.yaml --upload-certs
fi

mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
