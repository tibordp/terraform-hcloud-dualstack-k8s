# Admin kubeconfig, signed in Terraform from the cluster CA.

resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "admin" {
  private_key_pem = tls_private_key.admin.private_key_pem

  subject {
    common_name  = "kubernetes-admin"
    organization = "kubeadm:cluster-admins"
  }
}

resource "tls_locally_signed_cert" "admin" {
  cert_request_pem   = tls_cert_request.admin.cert_request_pem
  ca_private_key_pem = tls_private_key.ca["kubernetes"].private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca["kubernetes"].cert_pem

  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 720  # roll 30 days early; harmless for a leaf

  allowed_uses = ["client_auth", "digital_signature", "key_encipherment"]
}

locals {
  # Raw PEMs, exposed as outputs.
  certificate_authority_data = tls_self_signed_cert.ca["kubernetes"].cert_pem
  client_certificate_data    = tls_locally_signed_cert.admin.cert_pem
  client_key_data            = tls_private_key.admin.private_key_pem

  kubeconfig = yamlencode({
    apiVersion        = "v1"
    kind              = "Config"
    "current-context" = "kubernetes-admin@${var.name}"
    clusters = [{
      name = var.name
      cluster = {
        server                       = "https://${local.control_plane_endpoint}:6443"
        "certificate-authority-data" = base64encode(tls_self_signed_cert.ca["kubernetes"].cert_pem)
      }
    }]
    users = [{
      name = "kubernetes-admin"
      user = {
        "client-certificate-data" = base64encode(tls_locally_signed_cert.admin.cert_pem)
        "client-key-data"         = base64encode(tls_private_key.admin.private_key_pem)
      }
    }]
    contexts = [{
      name = "kubernetes-admin@${var.name}"
      context = {
        cluster = var.name
        user    = "kubernetes-admin"
      }
    }]
  })
}
