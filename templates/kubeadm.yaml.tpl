kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
---
kind: InitConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
certificateKey: "${certificate_key}"
localAPIEndpoint:
  advertiseAddress: "${advertise_address}"
  bindPort: 6443
---
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: v1.21.0
featureGates:
  IPv6DualStack: true
controllerManager:
  extraArgs:
    node-cidr-mask-size-ipv4: "24"
    node-cidr-mask-size-ipv6: "120"
networking:
  serviceSubnet: ${service_cidr_ipv6},${service_cidr_ipv4}
controlPlaneEndpoint: "${control_plane_endpoint}:6443"
---
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
# IPVS unfortunately breaks Hetzner LoadBalancer healthchecks
# mode: ipvs