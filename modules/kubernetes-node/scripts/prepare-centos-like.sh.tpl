#!/bin/bash
set -euo pipefail

# Kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf > /dev/null
overlay
br_netfilter
ip_tables
ip6_tables
wireguard
EOF
sudo modprobe -a overlay br_netfilter ip_tables ip6_tables

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf > /dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding        = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system

# Install prerequisites
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo > /dev/null
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

sudo dnf -qy config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf -qy install elrepo-release epel-release
sudo dnf -qy install containerd.io ipvsadm kmod-wireguard wireguard-tools iproute-tc

# Load Wireguard kernel module
sudo modprobe wireguard

# Enable systemd cgroups driver
sudo mkdir -p /etc/containerd
containerd config default | \
  grep -v 'SystemdCgroup' | \
  sed -re 's/(\s+)(\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\])/\1\2\n\1  SystemdCgroup = true/g' | \
  sudo tee /etc/containerd/config.toml >/dev/null

# Disable SELinux, if it is enabled
if [ "$(getenforce)" != "Permissive" ]; then
    sudo setenforce 0
    sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
fi

cat <<EOF | sudo tee /etc/sysconfig/kubelet > /dev/null
KUBELET_EXTRA_ARGS=--cloud-provider=external --node-ip=::
EOF

sudo dnf -qy install kubelet-${kubernetes_version}-0 kubeadm-${kubernetes_version}-0 kubectl-${kubernetes_version}-0 --disableexcludes=kubernetes
sudo systemctl enable --now containerd kubelet 

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
