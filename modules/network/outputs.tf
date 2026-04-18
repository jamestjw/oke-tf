output "vcn_id" {
  value = oci_core_vcn.this.id
}

output "endpoint_subnet_id" {
  value = oci_core_subnet.endpoint.id
}

output "worker_subnet_id" {
  value = oci_core_subnet.workers.id
}

output "pod_subnet_id" {
  value = oci_core_subnet.pods.id
}

output "lb_subnet_id" {
  value = oci_core_subnet.load_balancers.id
}

output "endpoint_nsg_id" {
  value = oci_core_network_security_group.endpoint.id
}

output "worker_nsg_id" {
  value = oci_core_network_security_group.workers.id
}

output "pod_nsg_id" {
  value = oci_core_network_security_group.pods.id
}

output "lb_nsg_id" {
  value = oci_core_network_security_group.load_balancers.id
}
