variable "compartment_ocid" {
  type = string
}

variable "name_prefix" {
  type = string
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
  type = list(string)
}

variable "bastion_client_cidrs" {
  type = list(string)
}

variable "freeform_tags" {
  type    = map(string)
  default = {}
}
