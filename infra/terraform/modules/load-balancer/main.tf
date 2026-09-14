# ──────────────────────────────────────────────
# Load Balancer module — reserved public IP for OKE ingress
# OKE manages the actual LB via Service annotations;
# this module reserves a public IP for DNS configuration.
# ──────────────────────────────────────────────

resource "oci_core_public_ip" "ingress" {
  compartment_id = var.compartment_id
  display_name   = "${var.prefix}-ingress-ip"
  lifetime       = "RESERVED"

  freeform_tags = {
    "project" = "walfa"
  }
}
