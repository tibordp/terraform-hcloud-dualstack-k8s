kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
---
kind: InitConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
%{ if ha_control_plane }
certificateKey: "${certificate_key}"
%{ endif }
localAPIEndpoint:
  advertiseAddress: "${advertise_address}"
  bindPort: 6443
---
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
kubernetesVersion: v1.21.0
featureGates:
  IPv6DualStack: true
networking:
  serviceSubnet: ${service_cidr_ipv4},${service_cidr_ipv6}
%{ if ha_control_plane }
controlPlaneEndpoint: "${control_plane_endpoint}:6443"
%{ endif }