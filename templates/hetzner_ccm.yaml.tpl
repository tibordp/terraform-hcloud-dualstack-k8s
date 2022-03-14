# NOTE: this release was tested against kubernetes v1.18.x

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-controller-manager
  namespace: kube-system
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: system:cloud-controller-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: cloud-controller-manager
    namespace: kube-system
---
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
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      serviceAccountName: cloud-controller-manager
      dnsPolicy: Default
      tolerations:
        # this taint is set by all kubelets running `--cloud-provider=external`
        # so we should tolerate it to schedule the cloud controller manager
        - key: "node.cloudprovider.kubernetes.io/uninitialized"
          value: "true"
          effect: "NoSchedule"
        - key: "CriticalAddonsOnly"
          operator: "Exists"
        # cloud controller manages should be able to run on masters
        - key: "node-role.kubernetes.io/master"
          effect: NoSchedule
          operator: Exists          
        - key: "node-role.kubernetes.io/control-plane"
          effect: NoSchedule
          operator: Exists          
        - key: "node.kubernetes.io/not-ready"
          effect: "NoSchedule"
      containers:
        - image: hetznercloud/hcloud-cloud-controller-manager:v1.12.1
          name: hcloud-cloud-controller-manager
          command:
            - "/bin/hcloud-cloud-controller-manager"
            - "--cloud-provider=hcloud"
            - "--leader-elect=false"
            - "--allow-untagged-cloud"
%{ if use_hcloud_network ~} 
            - "--allocate-node-cidrs=true"
            - "--cluster-cidr=${pod_cidr_ipv4}"
%{ endif ~}          
          resources:
            requests:
              cpu: 100m
              memory: 50Mi
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
