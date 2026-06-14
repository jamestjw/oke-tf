output "instance_id" {
  value = oci_core_instance.this.id
}

output "public_ip" {
  value = oci_core_instance.this.public_ip
}

output "private_ip" {
  value = oci_core_instance.this.private_ip
}

output "subnet_id" {
  value = oci_core_subnet.this.id
}

output "image_id" {
  value = local.image_id
}
