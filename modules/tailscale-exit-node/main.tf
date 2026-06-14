data "oci_core_images" "this" {
  compartment_id           = var.tenancy_ocid
  operating_system         = var.image_operating_system
  operating_system_version = var.image_operating_system_version
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

locals {
  image_id = data.oci_core_images.this.images[0].id
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    auth_key = var.auth_key
    hostname = var.hostname
    udp_port = var.udp_port
  })
}

resource "oci_core_security_list" "this" {
  compartment_id = var.compartment_ocid
  vcn_id         = var.vcn_id
  display_name   = "${var.name}-sl"
  freeform_tags  = var.freeform_tags

  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"

    udp_options {
      min = var.udp_port
      max = var.udp_port
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_subnet" "this" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = var.vcn_id
  cidr_block                 = var.subnet_cidr
  display_name               = "${var.name}-subnet"
  dns_label                  = "tsexit"
  route_table_id             = var.public_route_table_id
  security_list_ids          = [oci_core_security_list.this.id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = var.freeform_tags
}

resource "oci_core_instance" "this" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = var.name
  shape               = var.shape
  freeform_tags       = var.freeform_tags

  create_vnic_details {
    assign_public_ip = true
    display_name     = "${var.name}-vnic"
    hostname_label   = "tsexit"
    subnet_id        = oci_core_subnet.this.id
  }

  metadata = {
    user_data = base64encode(local.user_data)
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  lifecycle {
    precondition {
      condition     = trimspace(var.auth_key) != ""
      error_message = "auth_key must be set for the Tailscale exit node instance."
    }

  }
}
