# ──────────────────────────────────────────────
# Network module — VCN, subnets, gateways, NSGs for OKE
# ──────────────────────────────────────────────

locals {
  prefix = var.prefix
}

# ── VCN ──────────────────────────────────────

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${local.prefix}-vcn"
  dns_label      = var.vcn_dns_label
}

# ── Gateways ─────────────────────────────────

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-igw"
  enabled        = true
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-natgw"
}

data "oci_core_services" "all_oci_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-sgw"

  services {
    service_id = data.oci_core_services.all_oci_services.services[0].id
  }
}

# ── Route tables ─────────────────────────────

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-private-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_nat_gateway.this.id
  }

  route_rules {
    destination       = data.oci_core_services.all_oci_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }
}

# ── Subnets ──────────────────────────────────

resource "oci_core_subnet" "lb" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.lb_subnet_cidr
  display_name               = "${local.prefix}-lb-subnet"
  dns_label                  = "lb"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.public.id
}

resource "oci_core_subnet" "worker" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.worker_subnet_cidr
  display_name               = "${local.prefix}-worker-subnet"
  dns_label                  = "worker"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
}

resource "oci_core_subnet" "api" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.api_subnet_cidr
  display_name               = "${local.prefix}-api-subnet"
  dns_label                  = "api"
  prohibit_public_ip_on_vnic = var.api_endpoint_private
  route_table_id             = var.api_endpoint_private ? oci_core_route_table.private.id : oci_core_route_table.public.id
}

# ── Network Security Groups ──────────────────

resource "oci_core_network_security_group" "cluster" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-cluster-nsg"
}

resource "oci_core_network_security_group" "worker" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-worker-nsg"
}

resource "oci_core_network_security_group" "api" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-api-nsg"
}

resource "oci_core_network_security_group" "lb" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${local.prefix}-lb-nsg"
}

# ── NSG Rules: Cluster endpoint ← workers ────

resource "oci_core_network_security_group_security_rule" "cluster_from_worker_tcp443" {
  network_security_group_id = oci_core_network_security_group.cluster.id
  direction                 = "INGRESS"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.worker.id
  protocol                  = "6" # TCP
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "cluster_from_worker_tcp12250" {
  network_security_group_id = oci_core_network_security_group.cluster.id
  direction                 = "INGRESS"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.worker.id
  protocol                  = "6"
  tcp_options {
    destination_port_range {
      min = 12250
      max = 12250
    }
  }
}

# ── NSG Rules: Workers ← cluster ─────────────

resource "oci_core_network_security_group_security_rule" "worker_from_cluster_tcp12250" {
  network_security_group_id = oci_core_network_security_group.worker.id
  direction                 = "INGRESS"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.cluster.id
  protocol                  = "6"
  tcp_options {
    destination_port_range {
      min = 10250
      max = 12250
    }
  }
}

# Workers ← workers (inter-node communication)
resource "oci_core_network_security_group_security_rule" "worker_from_worker_all_tcp" {
  network_security_group_id = oci_core_network_security_group.worker.id
  direction                 = "INGRESS"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.worker.id
  protocol                  = "6" # all TCP
}

# Workers ← workers (VXLAN/UDP for Flannel)
resource "oci_core_network_security_group_security_rule" "worker_from_worker_udp" {
  network_security_group_id = oci_core_network_security_group.worker.id
  direction                 = "INGRESS"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.worker.id
  protocol                  = "17" # UDP
}

# Workers ← LB (health checks / traffic)
resource "oci_core_network_security_group_security_rule" "worker_from_lb_tcp" {
  network_security_group_id = oci_core_network_security_group.worker.id
  direction                 = "INGRESS"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.lb.id
  protocol                  = "6"
}

# Workers egress (all)
resource "oci_core_network_security_group_security_rule" "worker_egress_all" {
  network_security_group_id = oci_core_network_security_group.worker.id
  direction                 = "EGRESS"
  destination_type          = "CIDR_BLOCK"
  destination               = "0.0.0.0/0"
  protocol                  = "all"
}

# ── NSG Rules: API endpoint ──────────────────

# API NSG ingress: allow from worker NSG to 6443
resource "oci_core_network_security_group_security_rule" "api_from_worker_tcp6443" {
  network_security_group_id = oci_core_network_security_group.api.id
  direction                 = "INGRESS"
  source_type               = "NETWORK_SECURITY_GROUP"
  source                    = oci_core_network_security_group.worker.id
  protocol                  = "6"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# API NSG: allow public access if public endpoint
resource "oci_core_network_security_group_security_rule" "api_public_tcp6443" {
  count                     = var.api_endpoint_private ? 0 : 1
  network_security_group_id = oci_core_network_security_group.api.id
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  protocol                  = "6"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# ── NSG Rules: LB ────────────────────────────

# LB ingress: allow public HTTPS/HTTP
resource "oci_core_network_security_group_security_rule" "lb_ingress_tcp80" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  protocol                  = "6"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_ingress_tcp443" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  source_type               = "CIDR_BLOCK"
  source                    = "0.0.0.0/0"
  protocol                  = "6"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# LB egress to workers
resource "oci_core_network_security_group_security_rule" "lb_egress_to_worker" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "EGRESS"
  destination_type          = "NETWORK_SECURITY_GROUP"
  destination               = oci_core_network_security_group.worker.id
  protocol                  = "6"
}
