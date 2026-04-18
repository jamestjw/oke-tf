output "cluster_id" {
  value = oci_containerengine_cluster.this.id
}

output "cluster_private_endpoint" {
  value = oci_containerengine_cluster.this.endpoints[0].private_endpoint
}

output "cluster_vcn_hostname_endpoint" {
  value = oci_containerengine_cluster.this.endpoints[0].vcn_hostname_endpoint
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.this.id
}

output "node_image_id" {
  value = local.selected_node_image_id
}
