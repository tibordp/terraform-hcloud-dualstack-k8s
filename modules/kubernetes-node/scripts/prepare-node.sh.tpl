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
		export DEBIAN_FRONTEND=noninteractive

		# Install prerequisites
		apt-get -qq update
		apt-get -qq upgrade
		apt-get -qq install apt-transport-https ca-certificates curl gnupg lsb-release ipvsadm wireguard apparmor
		curl -fsSL https://download.docker.com/linux/$os_id/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
		curl -fsSL https://pkgs.k8s.io/core:/stable:/v${kubernetes_minor_version}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
		echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$os_id $(lsb_release -cs) stable" \
			>/etc/apt/sources.list.d/docker.list
		echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${kubernetes_minor_version}/deb/ /" \
			>/etc/apt/sources.list.d/kubernetes.list

		# Install container runtime
		apt-get -qq update
		apt-get -qq install containerd.io
	else
		# Install prerequisites
		dnf -qy upgrade

		cat <<-EOF > /etc/yum.repos.d/kubernetes.repo
			[kubernetes]
			name=Kubernetes
			baseurl=https://pkgs.k8s.io/core:/stable:/v${kubernetes_minor_version}/rpm/
			enabled=1
			gpgcheck=1
			gpgkey=https://pkgs.k8s.io/core:/stable:/v${kubernetes_minor_version}/rpm/repodata/repomd.xml.key
			exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
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
		apt-get -qq install kubelet=${kubernetes_version}-* kubeadm=${kubernetes_version}-* kubectl=${kubernetes_version}-*
		apt-mark hold kubelet kubeadm kubectl

		mkdir -p /etc/systemd/system/kubelet.service.d
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
		dnf -qy install kubelet-${kubernetes_version}-* kubeadm-${kubernetes_version}-* kubectl-${kubernetes_version}-* --disableexcludes=kubernetes
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
