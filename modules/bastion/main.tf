resource "oci_bastion_bastion" "this" {
  bastion_type                 = "standard"
  compartment_id               = var.compartment_ocid
  target_subnet_id             = var.target_subnet_id
  client_cidr_block_allow_list = var.client_cidr_block_allow_list
  max_session_ttl_in_seconds   = var.max_session_ttl_in_seconds
  name                         = var.name
  dns_proxy_status             = "DISABLED"
  freeform_tags                = var.freeform_tags
}
