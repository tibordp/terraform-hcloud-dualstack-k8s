---
# Source: hcloud-cloud-controller-manager/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hcloud-cloud-controller-manager
  namespace: kube-system
---
# Source: hcloud-cloud-controller-manager/templates/clusterrole.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: "system:hcloud-cloud-controller-manager"
rules:
  - apiGroups:
      - ""
    resources:
      - configmaps
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - create
      - patch
      - update
  - apiGroups:
      - ""
    resources:
      - nodes
    verbs:
      - "*"
  - apiGroups:
      - ""
    resources:
      - nodes/status
    verbs:
      - patch
  - apiGroups:
      - ""
    resources:
      - services
    verbs:
      - list
      - watch
  - apiGroups:
      - ""
    resources:
      - services/status
    verbs:
      - patch
      - update
  - apiGroups:
      - ""
    resources:
      - serviceaccounts
    verbs:
      - create
  - apiGroups:
      - coordination.k8s.io
    resources:
      - leases
    verbs:
      - create
      - get
      - list
      - watch
      - update
---
# Source: hcloud-cloud-controller-manager/templates/clusterrolebinding.yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  # The prefix ":restricted" originates from removing the cluster-admin role from HCCM.
  # Renaming the ClusterRoleBinding makes the migration easier for users.
  name: "system:hcloud-cloud-controller-manager:restricted"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: "system:hcloud-cloud-controller-manager"
subjects:
  - kind: ServiceAccount
    name: hcloud-cloud-controller-manager
    namespace: kube-system
---
# Source: hcloud-cloud-controller-manager/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hcloud-cloud-controller-manager
  namespace: kube-system
spec:
  replicas: 1
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: hcloud-cloud-controller-manager
  template:
    metadata:
      labels:
        app: hcloud-cloud-controller-manager
    spec:
      serviceAccountName: hcloud-cloud-controller-manager
      dnsPolicy: Default
      tolerations:
        # Allow HCCM itself to schedule on nodes that have not yet been initialized by HCCM.
        - key: "node.cloudprovider.kubernetes.io/uninitialized"
          value: "true"
          effect: "NoSchedule"
        - key: "CriticalAddonsOnly"
          operator: "Exists"

        # Allow HCCM to schedule on control plane nodes.
        - key: "node-role.kubernetes.io/master"
          effect: NoSchedule
          operator: Exists
        - key: "node-role.kubernetes.io/control-plane"
          effect: NoSchedule
          operator: Exists

        - key: "node.kubernetes.io/not-ready"
          effect: "NoExecute"
      containers:
        - name: hcloud-cloud-controller-manager
          args:
            - "--allow-untagged-cloud"
            - "--cloud-provider=hcloud"
            - "--route-reconciliation-period=30s"
            - "--webhook-secure-port=0"
            - "--leader-elect=false"
            - "--feature-gates=CloudControllerManagerWatchBasedRoutesReconciliation=false"
%{ if use_hcloud_network ~}
            - "--allocate-node-cidrs=true"
            - "--cluster-cidr=${pod_cidr_ipv4}"
%{ endif ~}
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: HCLOUD_TOKEN
              valueFrom:
                secretKeyRef:
                  name: hcloud
                  key: token
%{ if use_hcloud_network ~}
            - name: HCLOUD_NETWORK
              valueFrom:
                secretKeyRef:
                  name: hcloud
                  key: network
%{ endif ~}
            - name: HCLOUD_INSTANCES_ADDRESS_FAMILY
              value: dualstack
          image: docker.io/hetznercloud/hcloud-cloud-controller-manager:v1.30.1 # x-releaser-pleaser-version
          ports:
            - name: metrics
              containerPort: 8233
          resources:
            requests:
              cpu: 100m
              memory: 50Mi
      priorityClassName: "system-cluster-critical"
