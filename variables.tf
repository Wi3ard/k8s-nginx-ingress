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
  default     = "us-central1"
  description = "Region to create resources in"
  type        = string
}
