/*
 * Outputs.
 */

output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = data.kubernetes_service.nginx_ingress_controller.load_balancer_ingress[0].ip
}
