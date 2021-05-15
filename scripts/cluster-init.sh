#!/bin/bash
set -euo pipefail

if [[ "$HA_CONTROL_PLANE" == "1" ]]
then
  sudo kubeadm init --config cluster.yaml --upload-certs
else
  sudo kubeadm init --config cluster.yaml
fi

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config