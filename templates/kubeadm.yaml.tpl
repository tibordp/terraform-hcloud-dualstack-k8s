kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: systemd
---
kind: InitConfiguration
apiVersion: kubeadm.k8s.io/v1beta4
certificateKey: "${certificate_key}"
localAPIEndpoint:
  advertiseAddress: "${advertise_address}"
  bindPort: 6443
---
kind: ClusterConfiguration
apiVersion: kubeadm.k8s.io/v1beta4
kubernetesVersion: "v${kubernetes_version}"
apiServer:
  certSANs:
%{ for san in apiserver_cert_sans ~}
  - "${san}"
%{ endfor ~}
networking:
  podSubnet: "${pod_cidr_ipv4}"
%{ if primary_ip_family  == "ipv4" ~}
  serviceSubnet: "${service_cidr_ipv4},${service_cidr_ipv6}"
%{ else ~}
  serviceSubnet: "${service_cidr_ipv6},${service_cidr_ipv4}"
%{ endif ~}
controlPlaneEndpoint: "${control_plane_endpoint}:6443"
---
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
mode: ipvs
bindAddress: "::"
