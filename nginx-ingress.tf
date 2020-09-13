/*
 * Nginx ingress helm chart.
 */

resource "helm_release" "nginx_ingress" {
  chart         = "ingress-nginx"
  force_update  = true
  name          = "ingress-nginx"
  namespace     = "kube-system"
  recreate_pods = true
  repository    = "https://kubernetes.github.io/ingress-nginx"
  reuse_values  = true
  version       = "2.16.0"

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
    default-ssl-certificate: "kube-system/${local.dns_zone_name}-tls"
  metrics:
    enabled: true
    service:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "10254"
  publishService:
    enabled: true
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
  stats:
    enabled: true
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
