# ──────────────────────────────────────────────
# WALFA Free Environment — OCI Always Free
# ARM64 Ampere A1, OKE, network, OCIR, object storage
# ──────────────────────────────────────────────

# ── Data: availability domains ────────────────

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

locals {
  # Use the specified AD or fall back to the first available
  ad = var.availability_domain != "" ? var.availability_domain : data.oci_identity_availability_domains.this.availability_domains[0].name
}

# ── Modules ──────────────────────────────────

module "network" {
  source = "../../modules/network"

  compartment_id       = var.compartment_id
  prefix               = var.prefix
  api_endpoint_private = var.api_endpoint_private
}

module "oke" {
  source = "../../modules/oke"

  compartment_id       = var.compartment_id
  vcn_id               = module.network.vcn_id
  cluster_name         = var.cluster_name
  node_pool_name       = var.node_pool_name
  kubernetes_version   = var.kubernetes_version
  api_subnet_id        = module.network.api_subnet_id
  api_endpoint_private = var.api_endpoint_private
  api_nsg_id           = module.network.api_nsg_id
  worker_subnet_id     = module.network.worker_subnet_id
  worker_nsg_id        = module.network.worker_nsg_id
  lb_subnet_id         = module.network.lb_subnet_id
  node_ocpus           = var.node_ocpus
  node_memory_gbs      = var.node_memory_gbs
  boot_volume_size_gbs = var.boot_volume_size_gbs
  node_count           = var.node_count
  availability_domain  = local.ad
  ssh_public_key       = var.ssh_public_key
}

module "iam" {
  source = "../../modules/iam"

  tenancy_ocid                 = var.tenancy_ocid
  compartment_id               = var.compartment_id
  prefix                       = var.prefix
  github_actions_matching_rule = var.github_actions_matching_rule
}

module "ocir" {
  source = "../../modules/ocir"

  compartment_id = var.compartment_id
  prefix         = var.prefix
}

module "object_storage" {
  source = "../../modules/object-storage"

  compartment_id = var.compartment_id
  prefix         = var.prefix
}

module "load_balancer" {
  source = "../../modules/load-balancer"

  compartment_id = var.compartment_id
  prefix         = var.prefix
}

module "observability" {
  source = "../../modules/observability"

  compartment_id = var.compartment_id
  prefix         = var.prefix
}

module "compartments" {
  source = "../../modules/compartments"

  compartment_id = var.compartment_id
}
