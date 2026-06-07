# Cluster PKI roots.
#
# These are generated once and held in Terraform state, exactly like random_id:
# never renewed (the validity is set absurdly long, and there is no early
# renewal). kubeadm signs every leaf certificate from these CAs locally on each
# node and renews those leaves on its own schedule, so only the long-lived roots
# live here. Rotating a root is a deliberate, manual operation -- never an apply.
#
# NOTE: the CA private keys are sensitive cluster-root material and live in state
# (and are pushed to control-plane nodes over SSH). Protect the state backend.

locals {
  # ~100 years. The roots are write-once; rotate by hand if ever.
  ca_validity_hours = 876000
}

# --- Kubernetes CA (signs apiserver, kubelet client certs, kubeconfigs) ---
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  set_subject_key_id    = true
  validity_period_hours = local.ca_validity_hours
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "kubernetes"
  }
}

# --- Front-proxy CA (signs the aggregation-layer front-proxy client) ---
resource "tls_private_key" "front_proxy_ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "front_proxy_ca" {
  private_key_pem       = tls_private_key.front_proxy_ca.private_key_pem
  is_ca_certificate     = true
  set_subject_key_id    = true
  validity_period_hours = local.ca_validity_hours
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "front-proxy-ca"
  }
}

# --- etcd CA (stacked etcd: signs etcd server/peer/client certs) ---
resource "tls_private_key" "etcd_ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "etcd_ca" {
  private_key_pem       = tls_private_key.etcd_ca.private_key_pem
  is_ca_certificate     = true
  set_subject_key_id    = true
  validity_period_hours = local.ca_validity_hours
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "etcd-ca"
  }
}

# --- Service-account token signing keypair (sa.key / sa.pub; no certificate) ---
resource "tls_private_key" "sa" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# --- Bootstrap token for node discovery (kubeadm format: [a-z0-9]{6}.[a-z0-9]{16}) ---
resource "random_string" "bootstrap_token_id" {
  length  = 6
  upper   = false
  special = false
}

resource "random_string" "bootstrap_token_secret" {
  length  = 16
  upper   = false
  special = false
}

locals {
  bootstrap_token = "${random_string.bootstrap_token_id.result}.${random_string.bootstrap_token_secret.result}"

  # The eight root files kubeadm expects under /etc/kubernetes/pki on a
  # control-plane node. Pushed to each CP node before init/join runs.
  pki_files = {
    "pki/ca.crt"             = tls_self_signed_cert.ca.cert_pem
    "pki/ca.key"             = tls_private_key.ca.private_key_pem
    "pki/front-proxy-ca.crt" = tls_self_signed_cert.front_proxy_ca.cert_pem
    "pki/front-proxy-ca.key" = tls_private_key.front_proxy_ca.private_key_pem
    "pki/etcd/ca.crt"        = tls_self_signed_cert.etcd_ca.cert_pem
    "pki/etcd/ca.key"        = tls_private_key.etcd_ca.private_key_pem
    "pki/sa.key"             = tls_private_key.sa.private_key_pem
    "pki/sa.pub"             = tls_private_key.sa.public_key_pem
  }
}
