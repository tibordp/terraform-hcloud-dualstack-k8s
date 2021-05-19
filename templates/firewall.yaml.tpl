apiVersion: v1
kind: ConfigMap
metadata:
  name: ip-masq-agent
  namespace: kube-system
data:
  config: |
    nonMasqueradeCIDRs:
%{ for range in non_masquerade_ranges ~}
    - "${range}"
%{ endfor ~}
    resyncInterval: 60s
    masqLinkLocal: false
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    k8s-app: masq-agents
  name: masq-agents
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: masq-agents
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        k8s-app: masq-agents
    spec:
      containers:
%{ if filter_ingress_ipv6 ~}
      - name: anti-masq-agent
        image: tibordp/anti-masq-agent:latest
        imagePullPolicy: IfNotPresent
        args:
          - --masq-chain=ANTI-MASQ
          - --interface=eth0
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_ADMIN", "NET_RAW"]
        volumeMounts:
        - mountPath: /run/xtables.lock
          name: xtables-lock
          readOnly: false
%{ endif ~}          
      - name: ip-masq-agent
        image: k8s.gcr.io/networking/ip-masq-agent-amd64:v2.6.0
        args:
            - --masq-chain=IP-MASQ
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_ADMIN", "NET_RAW"]
        volumeMounts:
          - name: config
            mountPath: /etc/config          
          - mountPath: /run/xtables.lock
            name: xtables-lock
            readOnly: false            
      hostNetwork: true
      volumes:
      - name: config
        configMap:
          name: ip-masq-agent
          optional: true
          items:
            - key: config
              path: ip-masq-agent
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
      tolerations:
      - operator: Exists
      nodeSelector:
        kubernetes.io/os: linux