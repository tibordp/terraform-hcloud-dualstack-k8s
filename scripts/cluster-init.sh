#!/bin/bash
set -euo pipefail

# Initialize cluster
cat <<EOF | tee cluster.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
---
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: v1.21.0
featureGates:
  IPv6DualStack: true
networking:
  serviceSubnet: 10.255.0.0/16,fd18:d0e4:f87e:100::/112
EOF


if [[ ! -v APISERVER_ENDPOINT ]]
then
  sudo kubeadm init --config cluster.yaml
else
  cat <<EOF | tee -a cluster.yaml
controlPlaneEndpoint: "$APISERVER_ENDPOINT:6443"
---
kind: InitConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
certificateKey: "$CERTIFICATE_KEY"
EOF
  sudo kubeadm init --config cluster.yaml --upload-certs
fi


mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config