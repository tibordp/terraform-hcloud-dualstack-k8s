#!/bin/bash
set -euo pipefail
umask 0077

# Lay down the cluster PKI roots generated in Terraform. kubeadm signs every leaf
# certificate from these locally (and renews the leaves itself); only these roots
# are managed by Terraform, and they are never rewritten once a cluster exists.
install -d -m 0755 /etc/kubernetes/pki/etcd

%{ for path, content in pki_files ~}
cat > "/etc/kubernetes/${path}" <<'PEM_EOF'
${content}
PEM_EOF
chmod ${endswith(path, ".key") ? "0600" : "0644"} "/etc/kubernetes/${path}"
%{ endfor ~}
