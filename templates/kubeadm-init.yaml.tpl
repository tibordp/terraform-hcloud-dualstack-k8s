---
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "${advertise_address}"
  bindPort: 6443
bootstrapTokens:
  - token: "${bootstrap_token}"
    ttl: "0s"
    usages:
      - signing
      - authentication
    groups:
      - system:bootstrappers:kubeadm:default-node-token
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "v${kubernetes_version}"
controlPlaneEndpoint: "${control_plane_endpoint}:6443"
apiServer:
  certSANs:
%{ for san in apiserver_cert_sans ~}
    - "${san}"
%{ endfor ~}
networking:
  podSubnet: "${pod_cidr_ipv4}"
%{ if primary_ip_family == "ipv4" ~}
  serviceSubnet: "${service_cidr_ipv4},${service_cidr_ipv6}"
%{ else ~}
  serviceSubnet: "${service_cidr_ipv6},${service_cidr_ipv4}"
%{ endif ~}
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ${kube_proxy_mode}
bindAddress: "::"
