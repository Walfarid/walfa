# ──────────────────────────────────────────────
# IAM module — dynamic groups and policies for OKE, OCIR, GitHub Actions
# ──────────────────────────────────────────────

# ── Dynamic group for GitHub Actions OIDC federation ──

resource "oci_identity_dynamic_group" "github_actions" {
  compartment_id = var.tenancy_ocid
  name           = "${var.prefix}-gha"
  description    = "GitHub Actions OIDC federation for WALFA"
  matching_rule  = var.github_actions_matching_rule
}

# ── Policy: GitHub Actions → manage OKE and OCIR in walfa compartment ──
# NOTE: Requires tenancy admin privileges to create.
# Uncomment when admin access is available.
#
# resource "oci_identity_policy" "github_actions" {
#   compartment_id = var.tenancy_ocid
#   name           = "${var.prefix}-gha-policy"
#   description    = "GitHub Actions can manage OKE, OCIR and supporting resources"
#   statements = [
#     "Allow dynamic-group ${oci_identity_dynamic_group.github_actions.name} to manage cluster-family in compartment id ${var.compartment_id}",
#     "Allow dynamic-group ${oci_identity_dynamic_group.github_actions.name} to manage artifacts-family in compartment id ${var.compartment_id}",
#     "Allow dynamic-group ${oci_identity_dynamic_group.github_actions.name} to manage object-family in compartment id ${var.compartment_id}",
#     "Allow dynamic-group ${oci_identity_dynamic_group.github_actions.name} to use instance-family in compartment id ${var.compartment_id}",
#     "Allow dynamic-group ${oci_identity_dynamic_group.github_actions.name} to read network-family in compartment id ${var.compartment_id}",
#   ]
# }
