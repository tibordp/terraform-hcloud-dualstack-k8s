#!/bin/bash
set -euo pipefail

# Kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf > /dev/null
overlay
br_netfilter
ip6_tables
EOF
sudo modprobe -a overlay br_netfilter ip6_tables

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf > /dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding        = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system

# Install prerequisites
sudo apt-get -qq update
sudo apt-get -qq install apt-transport-https ca-certificates curl gnupg lsb-release ipvsadm wireguard apparmor
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo $ID)/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo $ID) $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

# Install container runtime and Kubernetes
sudo apt-get -qq update
sudo apt-get -qq install containerd.io kubelet=${kubernetes_version}-00 kubeadm=${kubernetes_version}-00 kubectl=${kubernetes_version}-00
sudo apt-mark hold kubelet kubeadm kubectl

# Enable systemd cgroups driver
sudo mkdir -p /etc/containerd
containerd config default | \
  grep -v 'SystemdCgroup' | \
  sed -re 's/(\s+)(\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\])/\1\2\n\1  SystemdCgroup = true/g' | \
  sudo tee /etc/containerd/config.toml >/dev/null

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/20-hcloud.conf > /dev/null
[Service]
Environment="KUBELET_EXTRA_ARGS=--cloud-provider=external --node-ip=::"
EOF

sudo systemctl daemon-reload
sudo systemctl restart containerd kubelet

# Determine the IPv6 pod subnet based on the /64 assigned to eth0 interface (take 2nd /80)
sudo mkdir -p /etc/wigglenet
sudo python3 <<EOF
import re
import os
import ipaddress
import itertools

addrs = os.popen("ip -6 addr show eth0 scope global").read()
addr = re.search(r"inet6 ([^ ]+/64) scope global", addrs, re.MULTILINE).group(1)
net = ipaddress.IPv6Network(addr, strict=False)
pod_subnet = next(itertools.islice(net.subnets(16), 1, None))

with open("/etc/wigglenet/cidrs.txt", "w") as f:
    print(pod_subnet, file=f)

print(f"Pod CIDR is {pod_subnet}")
EOF
