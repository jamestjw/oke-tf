variable "compartment_ocid" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "availability_domain" {
  type = string
}

variable "name" {
  type = string
}

variable "vcn_id" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "public_route_table_id" {
  type = string
}

variable "auth_key" {
  type      = string
  sensitive = true
}

variable "hostname" {
  type = string
}

variable "udp_port" {
  type    = number
  default = 41641
}

variable "shape" {
  type    = string
  default = "VM.Standard.E2.1.Micro"
}

variable "image_operating_system" {
  type    = string
  default = "Canonical Ubuntu"
}

variable "image_operating_system_version" {
  type    = string
  default = "24.04"
}

variable "boot_volume_size_in_gbs" {
  type    = number
  default = 50
}

variable "freeform_tags" {
  type    = map(string)
  default = {}
}
