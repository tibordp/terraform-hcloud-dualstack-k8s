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
apiServer:
  certSANs:
%{ for san in apiserver_cert_sans ~}
  - "${san}"
%{ endfor ~}
networking:
  podSubnet: "${pod_cidr_ipv4}"
  serviceSubnet: "${service_cidr_ipv6},${service_cidr_ipv4}"
controlPlaneEndpoint: "${control_plane_endpoint}:6443"
---
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
mode: ipvs