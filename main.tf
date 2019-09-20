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

variable "dns_zone_name" {
  description = "The unique name of the zone hosted by Google Cloud DNS"
  type        = string
}

variable "google_application_credentials" {
  description = "Path to GCE JSON key file (used in k8s secrets for accessing GCE resources). Normally equals to GOOGLE_APPLICATION_CREDENTIALS env var value."
  type        = string
}

variable "google_project_id" {
  description = "GCE project ID"
  type        = string
}

variable "region" {
  default     = "us-central1"
  description = "Region to create resources in"
  type        = string
}

/*
 * Local definitions.
 */

locals {
  module_path = replace(path.module, "\\", "/")
}

/*
 * Terraform providers.
 */

provider "google" {
  version = "~> 2.15"

  project = var.google_project_id
  region  = var.region
}

provider "helm" {
  version = "~> 0.10"
}

provider "kubernetes" {
  version = "~> 1.9"
}

provider "local" {
  version = "~> 1.3"
}

provider "null" {
  version = "~> 2.1"
}

provider "template" {
  version = "~> 2.1"
}

/*
 * GCS remote storage for storing Terraform state.
 */

terraform {
  backend "gcs" {
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
    enabled: true
    minReplicas: 1
    maxReplicas: 10
    targetCPUUtilizationPercentage: 75
    targetMemoryUtilizationPercentage: 75
  config:
    use-forwarded-headers: "true"
  extraArgs:
    default-ssl-certificate: "kube-system/${var.dns_zone_name}-tls"
  publishService:
    enabled: "true"
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi
  service:
    annotations:
      service.beta.kubernetes.io/external-traffic: OnlyLocal
    externalTrafficPolicy: "Local"
defaultBackend:
  service:
    annotations:
      kubernetes.io/ingress.class: "nginx"
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/from-to-www-redirect: "true"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
# Uncomment if you have GitLab installed.
# tcp:
#   22: "gitlab/gitlab-gitlab-shell:22"
EOF
  ]
}

# Data source for Traefik Helm chart.
data "kubernetes_service" "nginx_ingress_controller" {
  depends_on = [helm_release.nginx_ingress]

  metadata {
    name      = "${helm_release.nginx_ingress.metadata[0].name}-controller"
    namespace = helm_release.nginx_ingress.metadata[0].namespace
  }
}

# DNS zone managed by Google Cloud DNS.
data "google_dns_managed_zone" "default" {
  name = var.dns_zone_name
}

# Root A record.
resource "google_dns_record_set" "a_root" {
  name         = "${var.domain_name}."
  managed_zone = data.google_dns_managed_zone.default.name
  type         = "A"
  ttl          = 300

  rrdatas = [data.kubernetes_service.nginx_ingress_controller.load_balancer_ingress[0].ip]
}

# Wildcard A record.
resource "google_dns_record_set" "a_wildcard" {
  name         = "*.${var.domain_name}."
  managed_zone = data.google_dns_managed_zone.default.name
  type         = "A"
  ttl          = 300

  rrdatas = [data.kubernetes_service.nginx_ingress_controller.load_balancer_ingress[0].ip]
}

# cert-manager helm chart.
resource "helm_release" "cert_manager" {
  chart         = "stable/cert-manager"
  force_update  = true
  name          = "cert-manager"
  namespace     = "kube-system"
  recreate_pods = true
  reuse_values  = true

  values = [<<EOF
ingressShim:
  defaultIssuerName: "letsencrypt"
  defaultIssuerKind: "ClusterIssuer"
  defaultACMEChallengeType: "dns01"
  defaultACMEDNS01ChallengeProvider: "gcs-dns"
resources:
  requests:
    cpu: 10m
    memory: 32Mi
EOF
  ]
}

# Letsencrypt production issuer resources.
resource "kubernetes_secret" "gcs_service_account" {
  metadata {
    name      = "gcs-service-account"
    namespace = helm_release.cert_manager.metadata[0].namespace
  }

  data = {
    gcs.json = file(var.google_application_credentials)
  }
}

data "template_file" "letsencrypt_issuer" {
  template = file("${local.module_path}/templates/letsencrypt-issuer.tpl")

  vars = {
    acme_email                 = var.acme_email
    gcs_service_account_secret = kubernetes_secret.gcs_service_account.metadata[0].name
    google_project_id          = var.google_project_id
    namespace                  = helm_release.cert_manager.metadata[0].namespace
    name                       = "letsencrypt"
    # server                     = "https://acme-v02.api.letsencrypt.org/directory"
    # Uncomment to switch to Letsencrypt staging server.
    server = "https://acme-staging-v02.api.letsencrypt.org/directory"
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

# Wildcard certificate resource.
data "template_file" "wildcard_cert" {
  template = file("${local.module_path}/templates/wildcard-cert.tpl")

  vars = {
    domain_name   = var.domain_name
    dns_zone_name = var.dns_zone_name
    namespace     = helm_release.cert_manager.metadata[0].namespace
    issuer_name   = "letsencrypt"
  }
}

resource "local_file" "wildcard_cert" {
  content  = data.template_file.wildcard_cert.rendered
  filename = ".terraform/wildcard-cert.yaml"
}

resource "null_resource" "create_wildcard_cert" {
  depends_on = [local_file.wildcard_cert]

  provisioner "local-exec" {
    command     = "kubectl apply -f wildcard-cert.yaml"
    working_dir = ".terraform"
  }

  triggers = {
    config_rendered = data.template_file.wildcard_cert.rendered
  }
}

/*
 * Outputs.
 */

output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = data.kubernetes_service.nginx_ingress_controller.load_balancer_ingress[0].ip
}
