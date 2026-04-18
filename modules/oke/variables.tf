variable "tenancy_ocid" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_type" {
  type    = string
  default = "ENHANCED_CLUSTER"
}

variable "kubernetes_version" {
  type = string
}

variable "vcn_id" {
  type = string
}

variable "endpoint_subnet_id" {
  type = string
}

variable "worker_subnet_id" {
  type = string
}

variable "pod_subnet_id" {
  type = string
}

variable "lb_subnet_id" {
  type = string
}

variable "endpoint_nsg_id" {
  type = string
}

variable "worker_nsg_id" {
  type = string
}

variable "pod_nsg_id" {
  type = string
}

variable "node_pool_name" {
  type = string
}

variable "node_shape" {
  type = string
}

variable "node_count" {
  type = number
}

variable "node_ocpus" {
  type = number
}

variable "node_memory_in_gbs" {
  type = number
}

variable "boot_volume_size_in_gbs" {
  type    = number
  default = 50
}

variable "node_image_id" {
  type    = string
  default = null
}

variable "node_pool_os_arch" {
  type    = string
  default = "aarch64"
}

variable "services_cidr" {
  type    = string
  default = "10.96.0.0/16"
}

variable "ssh_public_key" {
  type    = string
  default = null
}

variable "freeform_tags" {
  type    = map(string)
  default = {}
}
