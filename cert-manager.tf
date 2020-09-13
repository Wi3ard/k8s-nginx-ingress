/*
 * cert-manager helm chart.
 */

resource "helm_release" "cert_manager" {
  chart         = "cert-manager"
  force_update  = true
  name          = "cert-manager"
  namespace     = "kube-system"
  recreate_pods = true
  repository    = "https://charts.jetstack.io"
  reuse_values  = true
  version       = "1.0.1"

  values = [<<EOF
ingressShim:
  defaultIssuerName: "letsencrypt"
  defaultIssuerKind: "ClusterIssuer"
  defaultACMEChallengeType: "http01"
installCRDs: true
resources:
  requests:
    cpu: 10m
    memory: 32Mi
EOF
  ]
}

# Letsencrypt issuer resources.
data "template_file" "letsencrypt_issuer" {
  template = file("${local.module_path}/templates/letsencrypt-issuer.tpl")

  vars = {
    acme_email = var.acme_email
    namespace  = helm_release.cert_manager.metadata[0].namespace
    name       = "letsencrypt"
    server     = "https://acme-v02.api.letsencrypt.org/directory"
    # Uncomment to switch to Letsencrypt staging server.
    # server = "https://acme-staging-v02.api.letsencrypt.org/directory"
  }
}

resource "local_file" "letsencrypt_issuer" {
  content  = data.template_file.letsencrypt_issuer.rendered
  filename = ".terraform/letsencrypt-issuer.yaml"
}

resource "null_resource" "create_letsencrypt_issuer" {
  depends_on = [local_file.letsencrypt_issuer]

  provisioner "local-exec" {
    command     = "kubectl apply -f letsencrypt-issuer.yaml"
    working_dir = ".terraform"
  }

  triggers = {
    config_rendered = data.template_file.letsencrypt_issuer.rendered
  }
}

# Default certificate resource.
data "template_file" "default_cert" {
  template = file("${local.module_path}/templates/default-cert.tpl")

  vars = {
    domain_name   = var.domain_name
    dns_zone_name = local.dns_zone_name
    namespace     = helm_release.cert_manager.metadata[0].namespace
    issuer_name   = "letsencrypt"
  }
}

resource "local_file" "default_cert" {
  content  = data.template_file.default_cert.rendered
  filename = ".terraform/default-cert.yaml"
}

resource "null_resource" "create_default_cert" {
  depends_on = [local_file.default_cert]

  provisioner "local-exec" {
    command     = "kubectl apply -f default-cert.yaml"
    working_dir = ".terraform"
  }

  triggers = {
    config_rendered = data.template_file.default_cert.rendered
  }
}
