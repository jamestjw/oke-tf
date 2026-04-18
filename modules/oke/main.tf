data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

data "oci_containerengine_node_pool_option" "this" {
  compartment_id                = var.compartment_ocid
  node_pool_k8s_version         = var.kubernetes_version
  node_pool_option_id           = "all"
  node_pool_os_arch             = var.node_pool_os_arch
  should_list_all_patch_versions = true
}

locals {
  selected_node_image_id = coalesce(var.node_image_id, data.oci_containerengine_node_pool_option.this.sources[0].image_id)
}

resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_ocid
  kubernetes_version = var.kubernetes_version
  name               = var.cluster_name
  type               = var.cluster_type
  vcn_id             = var.vcn_id
  freeform_tags      = var.freeform_tags

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  endpoint_config {
    is_public_ip_enabled = false
    nsg_ids              = [var.endpoint_nsg_id]
    subnet_id            = var.endpoint_subnet_id
  }

  image_policy_config {
    is_policy_enabled = false
  }

  options {
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    kubernetes_network_config {
      services_cidr = var.services_cidr
    }

    service_lb_config {
      backend_nsg_ids = [var.worker_nsg_id]
    }

    service_lb_subnet_ids = [var.lb_subnet_id]
  }
}

resource "oci_containerengine_node_pool" "this" {
  cluster_id          = oci_containerengine_cluster.this.id
  compartment_id      = var.compartment_ocid
  kubernetes_version  = var.kubernetes_version
  name                = var.node_pool_name
  node_shape          = var.node_shape
  ssh_public_key      = var.ssh_public_key
  freeform_tags       = var.freeform_tags

  node_config_details {
    size    = var.node_count
    nsg_ids = [var.worker_nsg_id]

    node_pool_pod_network_option_details {
      cni_type      = "OCI_VCN_IP_NATIVE"
      pod_nsg_ids   = [var.pod_nsg_id]
      pod_subnet_ids = [var.pod_subnet_id]
    }

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
      subnet_id           = var.worker_subnet_id
    }
  }

  node_shape_config {
    memory_in_gbs = var.node_memory_in_gbs
    ocpus         = var.node_ocpus
  }

  node_source_details {
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
    image_id                = local.selected_node_image_id
    source_type             = "IMAGE"
  }
}
