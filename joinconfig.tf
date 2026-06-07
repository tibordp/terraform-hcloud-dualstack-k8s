locals {
  provision_script = templatefile("${path.module}/modules/kubernetes-node/scripts/prepare-node.sh.tpl", {
    kubernetes_version       = var.kubernetes_version
    kubernetes_minor_version = replace(var.kubernetes_version, "/^(\\d+\\.\\d+).*$/", "$1")
  })

  # cluster-info kubeconfig used for kubeadm join discovery: API server endpoint +
  # the cluster CA, no credentials. This mirrors the kube-public/cluster-info format
  # kubeadm itself publishes -- a single unnamed cluster and no context. kubeadm
  # picks up Clusters[""], validates the API server's TLS against this CA, and uses
  # the bootstrap token for the kubelet bootstrap, so we never compute a CA hash.
  discovery_kubeconfig = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = ""
      cluster = {
        server                       = "https://${local.control_plane_endpoint}:6443"
        "certificate-authority-data" = base64encode(tls_self_signed_cert.ca.cert_pem)
      }
    }]
  })

  # Worker JoinConfiguration (no control-plane block); identical for every worker.
  worker_join_config = templatefile("${path.module}/templates/kubeadm-join.yaml.tpl", {
    control_plane     = false
    advertise_address = ""
    bootstrap_token   = local.bootstrap_token
  })
}

# cloud-init for externally-managed worker nodes (e.g. cluster-autoscaler):
# prepares the node, drops the discovery kubeconfig + join config, and joins.
data "cloudinit_config" "join_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content = "#cloud-config\n${yamlencode({
      write_files = [
        {
          path        = "/root/discovery.conf"
          permissions = "0600"
          content     = local.discovery_kubeconfig
        },
        {
          path        = "/root/kubeadm.yaml"
          permissions = "0600"
          content     = local.worker_join_config
        },
      ]
    })}"
  }

  part {
    content_type = "text/x-shellscript"
    content = join("\n", [
      local.provision_script,
      "test -f /etc/kubernetes/.terraform-provisioned || { kubeadm join --config /root/kubeadm.yaml && touch /etc/kubernetes/.terraform-provisioned; }",
    ])
  }
}
