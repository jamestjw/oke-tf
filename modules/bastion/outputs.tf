output "bastion_id" {
  value = oci_bastion_bastion.this.id
}

output "private_endpoint_ip_address" {
  value = oci_bastion_bastion.this.private_endpoint_ip_address
}
