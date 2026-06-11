#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

os_id="$(. /etc/os-release && echo "$ID")"
if [ -f "/etc/debian_version" ]; then
  is_debian_like=1
else
  is_debian_like=0
fi

install_prerequisites() {
  if [ "$is_debian_like" -eq 1 ]; then
    export DEBIAN_FRONTEND=noninteractive

    # Install prerequisites
    apt-get -qq update
    apt-get -qq -y install apt-transport-https ca-certificates curl gnupg ipvsadm nftables wireguard apparmor
    curl -fsSL "https://download.docker.com/linux/$os_id/gpg" | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${kubernetes_minor_version}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$os_id $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      >/etc/apt/sources.list.d/docker.list
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${kubernetes_minor_version}/deb/ /" \
      >/etc/apt/sources.list.d/kubernetes.list

    # Install container runtime
    apt-get -qq update
    apt-get -qq -y install containerd.io
  else
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${kubernetes_minor_version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${kubernetes_minor_version}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

    addrepo() {
      if dnf --version | grep -q dnf5; then
        dnf -qy config-manager addrepo "--from-repofile=$1"
      else
        dnf -qy config-manager --add-repo "$1"
      fi
    }

    if [ "$os_id" == "fedora" ]; then
      addrepo https://download.docker.com/linux/fedora/docker-ce.repo
      dnf -qy install containerd.io ipvsadm nftables wireguard-tools iproute-tc
    elif [ "$(. /etc/os-release && echo "$PLATFORM_ID")" = "platform:el9" ]; then
      # Wireguard is installed by default on EL9-like systems
      addrepo https://download.docker.com/linux/centos/docker-ce.repo
      dnf -qy install containerd.io ipvsadm nftables wireguard-tools iproute-tc
    else
      addrepo https://download.docker.com/linux/centos/docker-ce.repo
      dnf -qy install elrepo-release epel-release
      dnf -qy install containerd.io ipvsadm nftables kmod-wireguard wireguard-tools iproute-tc
    fi
  fi
}

configure_system() {
  # Disable SELinux, if it is enabled
  if [ -x "$(command -v getenforce)" ] && [ "$(getenforce)" = "Enforcing" ]; then
    setenforce 0
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  fi

  # Disable swap
  swapoff -a
  sed -i -E '/\sswap\s/ s/^#?/#/' /etc/fstab

  if [ -e /dev/zram0 ]; then
    # https://fedoraproject.org/wiki/Changes/SwapOnZRAM
    touch /etc/systemd/zram-generator.conf
    zramctl --reset /dev/zram0
  fi

  # Kernel modules
  cat <<EOF > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
ip_tables
ip6_tables
wireguard
EOF

  modprobe -a overlay br_netfilter ip_tables ip6_tables wireguard

  # Setup required sysctl params, these persist across reboots.
  cat <<EOF > /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.ipv6.conf.all.forwarding        = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

  sysctl --system
}

configure_containerd() {
  # Configure containerd to use the systemd cgroup driver
  mkdir -p /etc/containerd
  containerd config default >/etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
}

install_kubernetes() {
  if [ "$is_debian_like" -eq 1 ]; then
    apt-get -qq -y install kubelet=${kubernetes_version}-* kubeadm=${kubernetes_version}-* kubectl=${kubernetes_version}-*
    apt-mark hold kubelet kubeadm kubectl

    echo 'KUBELET_EXTRA_ARGS=--cloud-provider=external --node-ip=::' > /etc/default/kubelet

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
    if dnf --version | grep -q dnf5; then
      dnf -qy install kubelet-${kubernetes_version}-* kubeadm-${kubernetes_version}-* kubectl-${kubernetes_version}-* --setopt=disable_excludes=kubernetes
    else
      dnf -qy install kubelet-${kubernetes_version}-* kubeadm-${kubernetes_version}-* kubectl-${kubernetes_version}-* --disableexcludes=kubernetes
    fi
    systemctl enable --now containerd kubelet
  fi
}

install_prerequisites
configure_system
configure_containerd
install_kubernetes
