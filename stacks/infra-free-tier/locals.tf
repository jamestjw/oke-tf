locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed-by  = "terraform"
    layer       = "infra"
  }

  api_allowed_cidrs = length(var.api_allowed_cidrs) > 0 ? var.api_allowed_cidrs : [var.vcn_cidr]
}
