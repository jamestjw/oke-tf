output "vcn_id" {
  value = module.network.vcn_id
}

output "oke_cluster_id" {
  value = module.oke.cluster_id
}

output "oke_node_pool_id" {
  value = module.oke.node_pool_id
}

output "oke_private_endpoint" {
  value = module.oke.cluster_private_endpoint
}

output "oke_private_hostname_endpoint" {
  value = module.oke.cluster_vcn_hostname_endpoint
}

output "selected_node_image_id" {
  value = module.oke.node_image_id
}

output "bastion_id" {
  value = module.bastion.bastion_id
}

output "bastion_private_endpoint_ip" {
  value = module.bastion.private_endpoint_ip_address
}

output "kubeconfig_private_endpoint_command" {
  value = "oci ce cluster create-kubeconfig --cluster-id ${module.oke.cluster_id} --file $HOME/.kube/config --region ${var.region} --token-version 2.0.0 --kube-endpoint PRIVATE_ENDPOINT"
}
