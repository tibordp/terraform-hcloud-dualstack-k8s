# Cluster PKI roots.
#
# These are generated once and held in Terraform state, exactly like random_id:
# never renewed (the validity defaults to absurdly long, and there is no early
# renewal). kubeadm signs every leaf certificate from these CAs locally on each
# node and renews those leaves on its own schedule, so only the long-lived roots
# live here. Rotating a root is a deliberate, manual operation -- never an apply.
#
# NOTE: the CA private keys are sensitive cluster-root material and live in state
# (and are pushed to control-plane nodes over SSH). Protect the state backend.

# Every root below is write-once: `ignore_changes = all` makes Terraform never
# replace or update them once created, so no config edit, default change or
# provider upgrade can ever regenerate the cluster's root of trust on an existing
# cluster (a replacement would silently kill it). New clusters still pick up the
# current settings at creation time -- ignore_changes only applies to updates.
# Rotation is a deliberate, manual operation (taint), never an apply.

# The three CA roots, keyed by common name: "kubernetes" (signs apiserver, kubelet
# client certs, kubeconfigs), "front-proxy-ca" (the aggregation layer) and
# "etcd-ca" (stacked etcd: etcd server/peer/client certs).
locals {
  ca_common_names = toset(["kubernetes", "front-proxy-ca", "etcd-ca"])
}

resource "tls_private_key" "ca" {
  for_each = local.ca_common_names

  algorithm   = var.ca_key_algorithm
  rsa_bits    = var.ca_rsa_bits
  ecdsa_curve = var.ca_ecdsa_curve

  lifecycle {
    ignore_changes = all
  }
}

resource "tls_self_signed_cert" "ca" {
  for_each = local.ca_common_names

  private_key_pem       = tls_private_key.ca[each.key].private_key_pem
  is_ca_certificate     = true
  set_subject_key_id    = true
  validity_period_hours = var.ca_validity_period_hours
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = each.key
  }

  lifecycle {
    ignore_changes = all
  }
}

# --- Service-account token signing keypair (sa.key / sa.pub; no certificate) ---
resource "tls_private_key" "sa" {
  algorithm   = var.ca_key_algorithm
  rsa_bits    = var.ca_rsa_bits
  ecdsa_curve = var.ca_ecdsa_curve

  lifecycle {
    ignore_changes = all
  }
}

# --- Bootstrap token for node discovery (kubeadm format: [a-z0-9]{6}.[a-z0-9]{16}) ---
# The id half is the Secret name: public and held stable. The secret half is the
# actual credential and is rotatable; random_password keeps it (and everything
# derived from it) redacted in plan output.
resource "random_string" "bootstrap_token_id" {
  length  = 6
  upper   = false
  special = false
}

resource "random_password" "bootstrap_token_secret" {
  length  = 16
  upper   = false
  special = false
}

locals {
  bootstrap_token = "${random_string.bootstrap_token_id.result}.${random_password.bootstrap_token_secret.result}"

  bootstrap_token_manifest = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "bootstrap-token-${random_string.bootstrap_token_id.result}"
      namespace = "kube-system"
    }
    type = "bootstrap.kubernetes.io/token"
    stringData = {
      "token-id"                       = random_string.bootstrap_token_id.result
      "token-secret"                   = random_password.bootstrap_token_secret.result
      "usage-bootstrap-authentication" = "true"
      "usage-bootstrap-signing"        = "true"
      "auth-extra-groups"              = "system:bootstrappers:kubeadm:default-node-token"
    }
  })

  # The eight root files kubeadm expects under /etc/kubernetes/pki on a
  # control-plane node. Pushed to each CP node before init/join runs.
  pki_files = {
    "pki/ca.crt"             = tls_self_signed_cert.ca["kubernetes"].cert_pem
    "pki/ca.key"             = tls_private_key.ca["kubernetes"].private_key_pem
    "pki/front-proxy-ca.crt" = tls_self_signed_cert.ca["front-proxy-ca"].cert_pem
    "pki/front-proxy-ca.key" = tls_private_key.ca["front-proxy-ca"].private_key_pem
    "pki/etcd/ca.crt"        = tls_self_signed_cert.ca["etcd-ca"].cert_pem
    "pki/etcd/ca.key"        = tls_private_key.ca["etcd-ca"].private_key_pem
    "pki/sa.key"             = tls_private_key.sa.private_key_pem
    "pki/sa.pub"             = tls_private_key.sa.public_key_pem
  }
}
