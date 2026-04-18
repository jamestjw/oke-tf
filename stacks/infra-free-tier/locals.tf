locals {
  name_prefix = "${var.project_name}-${var.environment}"
  run_command_dynamic_group_name = "${local.name_prefix}-run-command-dg"
  run_command_policy_name        = "${local.name_prefix}-run-command-policy"

  common_tags = {
    project     = var.project_name
    environment = var.environment
    managed-by  = "terraform"
    layer       = "infra"
  }

  api_allowed_cidrs = length(var.api_allowed_cidrs) > 0 ? var.api_allowed_cidrs : [var.vcn_cidr]

  run_command_policy_statements = [
    "Allow dynamic-group ${local.run_command_dynamic_group_name} to use instance-agent-command-execution-family in compartment id ${var.compartment_ocid} where request.instance.id=target.instance.id",
  ]
}
