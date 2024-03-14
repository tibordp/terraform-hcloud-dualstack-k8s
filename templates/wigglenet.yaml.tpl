kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: wigglenet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - get
      - list
      - watch
      - update
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: wigglenet
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: wigglenet
subjects:
- kind: ServiceAccount
  name: wigglenet
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wigglenet
  namespace: kube-system
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: wigglenet
  namespace: kube-system
  labels:
    app: wigglenet
spec:
  selector:
    matchLabels:
      app: wigglenet
  template:
    metadata:
      labels:
        app: wigglenet
    spec:
      hostNetwork: true
      tolerations:
      - operator: Exists
      serviceAccountName: wigglenet
      containers:
      - name: wigglenet
        image: ghcr.io/tibordp/wigglenet:v0.4.2
        imagePullPolicy: IfNotPresent
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
          # Masquerade outgoing IPv4 traffic not destined
          # to pod on another node
        - name: MASQUERADE_IPV4
          value: "true"
          # Masquerade outgoing IPv6 traffic not destined
          # to pod on another node
        - name: MASQUERADE_IPV6
          value: "false"
          # Filter direct IPv4 traffic to pods from
          # outside the cluster
        - name: FILTER_IPV4
          value: "false"
          # Filter direct IPv6 traffic to pods from
          # outside the cluster
        - name: FILTER_IPV6
          value: "${filter_pod_ingress_ipv6}"
          # The source of IPv6 subnets for node pod networks
          # ("none", "spec", "file")
        - name: POD_CIDR_SOURCE_IPV4
          value: "spec"
          # The source of IPv4 subnets for node pod networks
          # ("none", "spec", "file")
        - name: POD_CIDR_SOURCE_IPV6
          value: "file"
          # The file from which to read the pod CIDRs if "file"
          # mode is used
        - name: POD_CIDR_SOURCE_PATH
          value: "/etc/wigglenet/cidrs.txt"
          # Use native routing instead of the overlay network
          # for IPv4 traffic
        - name: NATIVE_ROUTING_IPV4
          value: "${native_routing_ipv4}"
        volumeMounts:
        - name: cfg
          mountPath: /etc/wigglenet
        - name: cni-cfg
          mountPath: /etc/cni/net.d
        - name: xtables-lock
          mountPath: /run/xtables.lock
          readOnly: false
        - name: lib-modules
          mountPath: /lib/modules
          readOnly: true
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "100m"
            memory: "50Mi"
        securityContext:
          privileged: false
          capabilities:
            add: ["NET_RAW", "NET_ADMIN"]
      volumes:
      - name: cfg
        hostPath:
          path: /etc/wigglenet
      - name: cni-cfg
        hostPath:
          path: /etc/cni/net.d
      - name: xtables-lock
        hostPath:
          path: /run/xtables.lock
          type: FileOrCreate
      - name: lib-modules
        hostPath:
          path: /lib/modules
