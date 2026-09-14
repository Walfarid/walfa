# ──────────────────────────────────────────────
# OKE module — cluster + ARM64 Ampere A1 node pool
# ──────────────────────────────────────────────

# ── Data source: latest OKE-optimised image for ARM64 ──

data "oci_containerengine_node_pool_option" "this" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_id
}

locals {
  # Filter for Oracle Linux 8+ ARM64 OKE image
  all_sources = data.oci_containerengine_node_pool_option.this.sources

  arm64_images = [
    for s in local.all_sources : s
    if can(regex("Oracle-Linux-.*aarch64", s.source_name))
    && can(regex("OKE-${var.kubernetes_version}", s.source_name))
  ]

  # Fallback: any aarch64 image (latest available)
  fallback_images = [
    for s in local.all_sources : s
    if can(regex("Oracle-Linux-.*aarch64", s.source_name))
  ]

  image_id = length(local.arm64_images) > 0 ? local.arm64_images[0].image_id : (length(local.fallback_images) > 0 ? local.fallback_images[0].image_id : "")
}

# ── OKE Cluster ──────────────────────────────

resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_id
  kubernetes_version = var.kubernetes_version
  name               = var.cluster_name
  vcn_id             = var.vcn_id
  type               = "ENHANCED_CLUSTER"

  cluster_pod_network_options {
    cni_type = "FLANNEL_OVERLAY"
  }

  endpoint_config {
    is_public_ip_enabled = !var.api_endpoint_private
    subnet_id            = var.api_subnet_id
    nsg_ids              = [var.api_nsg_id]
  }

  options {
    service_lb_subnet_ids = [var.lb_subnet_id]

    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }

  freeform_tags = {
    "project" = "walfa"
  }
}

# ── Node Pool: ARM64 Ampere A1 ───────────────

resource "oci_containerengine_node_pool" "this" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_id
  kubernetes_version = var.kubernetes_version
  name               = var.node_pool_name
  ssh_public_key     = var.ssh_public_key

  node_shape = "VM.Standard.A1.Flex"

  node_shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_gbs
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gbs
  }

  node_config_details {
    size = var.node_count

    placement_configs {
      availability_domain = var.availability_domain
      subnet_id           = var.worker_subnet_id
    }

    nsg_ids = [var.worker_nsg_id]
  }

  initial_node_labels {
    key   = "node.kubernetes.io/pool"
    value = "walfa-workers"
  }

  freeform_tags = {
    "project" = "walfa"
    "pool"    = "a1-flex"
  }
}
