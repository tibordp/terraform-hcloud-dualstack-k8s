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

# Install prerequisites
sudo apt-get update -qq
sudo apt-get install -qq apt-transport-https ca-certificates curl gnupg lsb-release ipvsadm wireguard
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install container runtime and Kubernetes
sudo apt-get update -qq
sudo apt-get install -qq containerd.io kubelet=1.21.1-00 kubeadm=1.21.1-00 kubectl=1.21.1-00
apt-mark hold kubelet kubeadm kubectl

# Enable systemd cgroups driver
sudo mkdir -p /etc/containerd
containerd config default | \
  perl -i -pe 's/(\s+)(\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\])/\1\2\n\1  SystemdCgroup = true/g' | \
  sudo tee /etc/containerd/config.toml > /dev/null

# Necessary for out-of-tree cloud providers as of 1.21.1 (soon to be deprecated)
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
