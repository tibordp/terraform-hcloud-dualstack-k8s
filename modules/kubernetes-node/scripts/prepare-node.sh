#!/bin/bash
set -euo pipefail

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding        = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

# Install CRI
sudo apt-get update
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  ipvsadm \
  wireguard

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo \
  "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y containerd.io

# Enable systemd cgroups driver
sudo mkdir -p /etc/containerd
containerd config default | \
  perl -i -pe 's/(\s+)(\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\])/\1\2\n\1  SystemdCgroup = true/g' | \
  sudo tee /etc/containerd/config.toml

sudo systemctl restart containerd

# Install Kubernetes
sudo apt-get install -y kubelet kubeadm kubectl

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/20-hcloud.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--cloud-provider=external"
EOF

kubeadm config images pull
sudo systemctl restart kubelet