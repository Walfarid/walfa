# ──────────────────────────────────────────────
# Object Storage module — application media bucket
# ──────────────────────────────────────────────

data "oci_objectstorage_namespace" "this" {}

resource "oci_objectstorage_bucket" "media" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "${var.prefix}-media"
  access_type    = "ObjectRead"
  storage_tier   = "Standard"
  versioning     = "Enabled"

  freeform_tags = {
    "project" = "walfa"
    "tier"    = "application"
  }
}
