# ──────────────────────────────────────────────
# Compartments module — passes through the compartment ID
# Sub-compartments can be added here if needed later.
# ──────────────────────────────────────────────

data "oci_identity_compartment" "this" {
  id = var.compartment_id
}
