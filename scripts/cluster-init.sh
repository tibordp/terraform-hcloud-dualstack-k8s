#!/bin/bash
set -euo pipefail

# Initialize cluster
cat <<EOF | tee cluster.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: v1.21.0
featureGates:
  IPv6DualStack: true
networking:
  serviceSubnet: 10.255.0.0/16,fd18:d0e4:f87e:100::/112
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF

kubeadm init --config cluster.yaml
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config