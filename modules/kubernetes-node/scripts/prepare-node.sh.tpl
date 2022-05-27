#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then 
  echo "This script must be run as root"
  exit 1
fi

os_id="$(. /etc/os-release && echo $ID)"
if [ -f "/etc/debian_version" ]; then 
	is_debian_like=1
else 
	is_debian_like=0
fi

install_prerequisites() {
	if [ $is_debian_like == 1 ]; then 
		# Install prerequisites
		apt-get -qq update
		apt-get -qq install apt-transport-https ca-certificates curl gnupg lsb-release ipvsadm wireguard apparmor
		curl -fsSL https://download.docker.com/linux/$os_id/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
		curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
		echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$os_id $(lsb_release -cs) stable" \
			>/etc/apt/sources.list.d/docker.list
		echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" \
			>/etc/apt/sources.list.d/kubernetes.list

		# Install container runtime
		apt-get -qq update
		apt-get -qq install containerd.io 
	else 
		# Install prerequisites
		
		cat <<-EOF > /etc/yum.repos.d/kubernetes.repo
			[kubernetes]
			name=Kubernetes
			baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
			enabled=1
			gpgcheck=1
			repo_gpgcheck=1
			gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
			exclude=kubelet kubeadm kubectl
			EOF

		if [ "$os_id" == "fedora" ]; then
			dnf -qy config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
			dnf -qy install containerd.io ipvsadm wireguard-tools iproute-tc
		elif [ "$(. /etc/os-release && echo $PLATFORM_ID)" = "platform:el9" ]; then
			# Wireguard is installed by default on EL9-like systems
			dnf -qy config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
			dnf -qy install containerd.io ipvsadm wireguard-tools iproute-tc
		else
			dnf -qy config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
			dnf -qy install elrepo-release epel-release
			dnf -qy install containerd.io ipvsadm kmod-wireguard wireguard-tools iproute-tc
		fi
	fi
}

configure_system() {
	# Disable SELinux, if it is enabled
	if [ -x "$(command -v getenforce)" ] && [ "$(getenforce)" != "Permissive" ]; then
		setenforce 0
		sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
	fi

	# Disable swap
	if grep -q '/dev/zram0' /proc/swaps; then
		# https://fedoraproject.org/wiki/Changes/SwapOnZRAM
		touch /etc/systemd/zram-generator.conf
		swapoff /dev/zram0
		zramctl --reset /dev/zram0
	fi

	# Kernel modules
	cat <<-EOF > /etc/modules-load.d/containerd.conf
		overlay
		br_netfilter
		ip_tables
		ip6_tables
		wireguard
		EOF

	modprobe -a overlay br_netfilter ip_tables ip6_tables wireguard

	# Setup required sysctl params, these persist across reboots.
	cat <<-EOF > /etc/sysctl.d/99-kubernetes-cri.conf
		net.bridge.bridge-nf-call-iptables  = 1
		net.ipv4.ip_forward                 = 1
		net.ipv6.conf.all.forwarding        = 1
		net.bridge.bridge-nf-call-ip6tables = 1
		EOF

	sysctl --system
}

configure_containerd() {
	# Enable systemd cgroups driver
	mkdir -p /etc/containerd
	containerd config default | \
		grep -v 'SystemdCgroup' | \
		sed -re 's/(\s+)(\[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options\])/\1\2\n\1  SystemdCgroup = true/g' \
			> /etc/containerd/config.toml
}

install_kubernetes() {
	if [ $is_debian_like == 1 ]; then 
		apt-get -qq install kubelet=${kubernetes_version}-00 kubeadm=${kubernetes_version}-00 kubectl=${kubernetes_version}-00
		apt-mark hold kubelet kubeadm kubectl

		cat <<-EOF > /etc/systemd/system/kubelet.service.d/20-hcloud.conf
			[Service]
			Environment="KUBELET_EXTRA_ARGS=--cloud-provider=external --node-ip=::"
			EOF

		systemctl daemon-reload
		systemctl restart containerd kubelet
	else
		if [ "$os_id" == "fedora" ]; then
			# Fedora containernetworking-plugins RPM installs the plugins in /usr/libexec/cni/
			# https://src.fedoraproject.org/rpms/containernetworking-plugins/blob/rawhide/f/containernetworking-plugins.spec
			mkdir -p /opt/cni
			ln -s /usr/libexec/cni/ /opt/cni/bin
		fi 

		echo 'KUBELET_EXTRA_ARGS=--cloud-provider=external --node-ip=::' > /etc/sysconfig/kubelet
		dnf -qy install kubelet-${kubernetes_version}-0 kubeadm-${kubernetes_version}-0 kubectl-${kubernetes_version}-0 --disableexcludes=kubernetes
		systemctl enable --now containerd kubelet
	fi
}

configure_wigglenet() {
	# Determine the IPv6 pod subnet based on the /64 assigned to eth0 interface (take 2nd /80)
	mkdir -p /etc/wigglenet
	python3 <<-EOF
		import re
		import os
		import ipaddress
		import itertools

		addrs = os.popen("ip -6 addr show eth0 scope global").read()
		addr = re.search(r"inet6 ([^ ]+/64) scope global", addrs, re.MULTILINE).group(1)
		net = ipaddress.IPv6Network(addr, strict=False)
		pod_subnet = next(itertools.islice(net.subnets(16), 1, None))
		print(pod_subnet, file=open("/etc/wigglenet/cidrs.txt", "w"))
		print(f"Pod CIDR is {pod_subnet}")
		EOF
}

install_prerequisites
configure_system
configure_containerd
install_kubernetes
configure_wigglenet
