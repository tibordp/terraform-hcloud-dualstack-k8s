#!/bin/bash
set -euo pipefail

if [ -z "$HCLOUD_TOKEN" ]
then
    echo "\$HCLOUD_TOKEN is empty"
    exit 1
fi

# Initialize cluster
cat <<EOF | tee cluster.yaml
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: v1.21.0
featureGates:
  IPv6DualStack: true
networking:
  podSubnet: 10.244.0.0/16,fd18:d0e4:f87e:0::/56
  serviceSubnet: 10.96.0.0/16,fd18:d0e4:f87e:100::/112
---
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
EOF

kubeadm init --config cluster.yaml

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install CNI
curl -LO https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin

cilium install --version v1.10.0-rc1 \
  --ipam kubernetes \
  --config enable-ipv6=true,enable-ipv6-masquerade=true,egress-masquerade-interfaces=eth0,ipam=kubernetes,enable-bpf-masquerade=false

# Install cloud provider
kubectl -n kube-system create secret generic hcloud --from-literal=token="$HCLOUD_TOKEN"
kubectl apply -f https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/latest/download/ccm.yaml

# Install storage provider
kubectl -n kube-system create secret generic hcloud-csi --from-literal=token="$HCLOUD_TOKEN"
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/v1.5.3/deploy/kubernetes/hcloud-csi.yml
