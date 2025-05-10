---
# Source: hcloud-cloud-controller-manager/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hcloud-cloud-controller-manager
  namespace: kube-system
---
# Source: hcloud-cloud-controller-manager/templates/clusterrolebinding.yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: "system:hcloud-cloud-controller-manager"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
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
          image: docker.io/hetznercloud/hcloud-cloud-controller-manager:v1.24.0 # x-releaser-pleaser-version
          ports:
            - name: metrics
              containerPort: 8233
          resources:
            requests:
              cpu: 100m
              memory: 50Mi
      priorityClassName: system-cluster-critical
