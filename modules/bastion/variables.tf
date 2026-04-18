variable "compartment_ocid" {
  type = string
}

variable "name" {
  type = string
}

variable "target_subnet_id" {
  type = string
}

variable "client_cidr_block_allow_list" {
  type = list(string)
}

variable "max_session_ttl_in_seconds" {
  type    = number
  default = 10800
}

variable "freeform_tags" {
  type    = map(string)
  default = {}
}
