/*
 * Input variables.
 */

variable "acme_email" {
  description = "Admin e-mail for Let's Encrypt"
  type        = string
}

variable "domain_name" {
  description = "Root domain name for the stack"
  type        = string
}

variable "region" {
  default     = "us-east-1"
  description = "Region to create resources in"
  type        = string
}

/*
 * Local definitions.
 */

locals {
  dns_zone_name = replace(var.domain_name, ".", "-")
  module_path   = replace(path.module, "\\", "/")
}

/*
 * Terraform providers.
 */

provider "aws" {
  region  = var.region
  version = "~> 2.42"
}

provider "helm" {
  version = "~> 0.10"
}

provider "kubernetes" {
  version = "~> 1.10"
}

provider "local" {
  version = "~> 1.4"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

/*
 * S3 remote storage for storing Terraform state.
 */

terraform {
  backend "s3" {
    encrypt = true
  }
}

/*
 * Terraform resources.
 */

# Nginx ingress helm chart.
resource "helm_release" "nginx_ingress" {
  chart         = "stable/nginx-ingress"
  force_update  = true
  name          = "nginx-ingress"
  namespace     = "kube-system"
  recreate_pods = true
  reuse_values  = true

  values = [<<EOF
controller:
  autoscaling:
    enabled: false
    minReplicas: 4
    maxReplicas: 12
    targetCPUUtilizationPercentage: 75
    targetMemoryUtilizationPercentage: 75
  config:
    use-forwarded-headers: "false"
    use-proxy-protocol: "true"
  extraArgs:
    default-ssl-certificate: "kube-system/${local.dns_zone_name}-tls"
  metrics:
    enabled: true
    service:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "10254"
    serviceMonitor:
      enabled: true
  publishService:
    enabled: true
  resources:
    limits:
      cpu: 250m
      memory: 400Mi
    requests:
      cpu: 100m
      memory: 200Mi
  stats:
    enabled: true
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: '*'
    externalTrafficPolicy: "Local"
defaultBackend:
  service:
    annotations:
      kubernetes.io/ingress.class: "nginx"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/from-to-www-redirect: "true"
EOF
  ]
}

# Data source for Traefik Helm chart.
data "kubernetes_service" "nginx_ingress_controller" {
  depends_on = [helm_release.nginx_ingress]

  metadata {
    name      = "${helm_release.nginx_ingress.metadata.0.name}-controller"
    namespace = helm_release.nginx_ingress.metadata.0.namespace
  }
}

# cert-manager helm chart.
data "helm_repository" "jetstack" {
  name = "jetstack"
  url  = "https://charts.jetstack.io"
}

resource "helm_release" "cert_manager" {
  chart         = "jetstack/cert-manager"
  force_update  = true
  name          = "cert-manager"
  namespace     = "kube-system"
  recreate_pods = true
  repository    = data.helm_repository.jetstack.metadata[0].name
  reuse_values  = true

  values = [<<EOF
ingressShim:
  defaultIssuerName: "letsencrypt"
  defaultIssuerKind: "ClusterIssuer"
  defaultACMEChallengeType: "http01"
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
    namespace  = helm_release.cert_manager.metadata.0.namespace
    name       = "letsencrypt"

    server = "https://acme-v02.api.letsencrypt.org/directory"
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

data "template_file" "gitlab_letsencrypt_issuer" {
  template = file("${local.module_path}/templates/gitlab-letsencrypt-issuer.tpl")

  vars = {
    acme_email = var.acme_email
    namespace  = helm_release.cert_manager.metadata.0.namespace
    name       = "gitlab-letsencrypt"

    server = "https://acme-v02.api.letsencrypt.org/directory"
    # Uncomment to switch to Letsencrypt staging server.
    # server = "https://acme-staging-v02.api.letsencrypt.org/directory"
  }
}

resource "local_file" "gitlab_letsencrypt_issuer" {
  content  = data.template_file.gitlab_letsencrypt_issuer.rendered
  filename = ".terraform/gitlab-letsencrypt-issuer.yaml"
}

resource "null_resource" "create_gitlab_letsencrypt_issuer" {
  depends_on = [local_file.gitlab_letsencrypt_issuer]

  provisioner "local-exec" {
    command     = "kubectl apply -f gitlab-letsencrypt-issuer.yaml"
    working_dir = ".terraform"
  }

  triggers = {
    config_rendered = data.template_file.gitlab_letsencrypt_issuer.rendered
  }
}

# Default certificate resource.
data "template_file" "default_cert" {
  template = file("${local.module_path}/templates/default-cert.tpl")

  vars = {
    domain_name   = var.domain_name
    dns_zone_name = local.dns_zone_name
    namespace     = helm_release.cert_manager.metadata.0.namespace
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

/*
 * Outputs.
 */

output "load_balancer_hostname" {
  description = "Host name of the load balancer"
  value       = data.kubernetes_service.nginx_ingress_controller.load_balancer_ingress.0.hostname
}
