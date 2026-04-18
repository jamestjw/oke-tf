variable "tenancy_ocid" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "region" {
  type = string
}

variable "oci_config_profile" {
  type    = string
  default = null
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "cluster_type" {
  type    = string
  default = "ENHANCED_CLUSTER"
}

variable "vcn_cidr" {
  type = string
}

variable "endpoint_subnet_cidr" {
  type = string
}

variable "worker_subnet_cidr" {
  type = string
}

variable "pod_subnet_cidr" {
  type = string
}

variable "lb_subnet_cidr" {
  type = string
}

variable "api_allowed_cidrs" {
  type    = list(string)
  default = []
}

variable "bastion_client_cidrs" {
  type = list(string)
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

variable "node_pool_os_arch" {
  type    = string
  default = "aarch64"
}

variable "node_image_id" {
  type    = string
  default = null
}

variable "boot_volume_size_in_gbs" {
  type    = number
  default = 50
}

variable "services_cidr" {
  type    = string
  default = "10.96.0.0/16"
}

variable "ssh_public_key" {
  type    = string
  default = null
}

variable "bastion_max_session_ttl_in_seconds" {
  type    = number
  default = 10800
}

variable "enable_run_command" {
  type    = bool
  default = false
}
