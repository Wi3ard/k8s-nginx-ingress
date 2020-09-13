/*
 * Local definitions.
 */

locals {
  dns_zone_name = "${replace(var.domain_name, ".", "-")}"
  module_path   = replace(path.module, "\\", "/")
}
