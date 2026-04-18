module "network" {
  source = "../../modules/network"

  compartment_ocid    = var.compartment_ocid
  name_prefix         = local.name_prefix
  vcn_cidr            = var.vcn_cidr
  endpoint_subnet_cidr = var.endpoint_subnet_cidr
  worker_subnet_cidr  = var.worker_subnet_cidr
  pod_subnet_cidr     = var.pod_subnet_cidr
  lb_subnet_cidr      = var.lb_subnet_cidr
  api_allowed_cidrs   = local.api_allowed_cidrs
  bastion_client_cidrs = var.bastion_client_cidrs
  freeform_tags       = local.common_tags
}

module "oke" {
  source = "../../modules/oke"

  tenancy_ocid          = var.tenancy_ocid
  compartment_ocid      = var.compartment_ocid
  cluster_name          = var.cluster_name
  cluster_type          = var.cluster_type
  kubernetes_version    = var.kubernetes_version
  vcn_id                = module.network.vcn_id
  endpoint_subnet_id    = module.network.endpoint_subnet_id
  worker_subnet_id      = module.network.worker_subnet_id
  pod_subnet_id         = module.network.pod_subnet_id
  lb_subnet_id          = module.network.lb_subnet_id
  endpoint_nsg_id       = module.network.endpoint_nsg_id
  worker_nsg_id         = module.network.worker_nsg_id
  pod_nsg_id            = module.network.pod_nsg_id
  node_pool_name        = "${local.name_prefix}-workers"
  node_shape            = var.node_shape
  node_count            = var.node_count
  node_ocpus            = var.node_ocpus
  node_memory_in_gbs    = var.node_memory_in_gbs
  node_pool_os_arch     = var.node_pool_os_arch
  node_image_id         = var.node_image_id
  boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  services_cidr         = var.services_cidr
  ssh_public_key        = var.ssh_public_key
  freeform_tags         = local.common_tags
}

module "bastion" {
  source = "../../modules/bastion"

  compartment_ocid               = var.compartment_ocid
  name                           = "${local.name_prefix}-bastion"
  target_subnet_id               = module.network.lb_subnet_id
  client_cidr_block_allow_list   = var.bastion_client_cidrs
  max_session_ttl_in_seconds     = var.bastion_max_session_ttl_in_seconds
  freeform_tags                  = local.common_tags
}

resource "oci_identity_dynamic_group" "run_command" {
  count = var.enable_run_command ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = local.run_command_dynamic_group_name
  description    = "Allows instances in the ${var.environment} compartment to consume OCI Run Command jobs."
  matching_rule  = "All {instance.compartment.id = '${var.compartment_ocid}'}"
}

resource "oci_identity_policy" "run_command" {
  count = var.enable_run_command ? 1 : 0

  compartment_id = var.tenancy_ocid
  name           = local.run_command_policy_name
  description    = "Allows instances in the ${var.environment} compartment to execute OCI Run Command jobs."
  statements     = local.run_command_policy_statements
}
