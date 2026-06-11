---
apiVersion: kubeadm.k8s.io/v1beta4
kind: JoinConfiguration
discovery:
  file:
    kubeConfigPath: /root/discovery.conf
  tlsBootstrapToken: "${bootstrap_token}"
%{ if control_plane ~}
controlPlane:
  localAPIEndpoint:
    advertiseAddress: "${advertise_address}"
    bindPort: 6443
%{ endif ~}
