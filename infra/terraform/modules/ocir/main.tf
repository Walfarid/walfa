# ──────────────────────────────────────────────
# OCIR module — container repositories for each WALFA service
# ──────────────────────────────────────────────

resource "oci_artifacts_container_repository" "services" {
  for_each = toset(var.repositories)

  compartment_id = var.compartment_id
  display_name   = "${var.prefix}/${each.value}"
  is_public      = false

  freeform_tags = {
    "project" = "walfa"
    "service" = each.value
  }
}
