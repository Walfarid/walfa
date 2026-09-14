# ──────────────────────────────────────────────
# WALFA Bootstrap — local state, no remote backend
# Creates: compartment, state bucket, dynamic group, IAM policies
# ──────────────────────────────────────────────

data "oci_objectstorage_namespace" "this" {}

# ── Compartment ──────────────────────────────

resource "oci_identity_compartment" "walfa" {
  compartment_id = var.compartment_ocid
  name           = var.project_name
  description    = "WALFA platform resources"
  enable_delete  = true
}

# ── Object Storage bucket for Terraform state ─

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = oci_identity_compartment.walfa.id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = "${var.project_name}-tfstate"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
}

# ── Dynamic group for Terraform automation ────

resource "oci_identity_dynamic_group" "terraform" {
  compartment_id = var.compartment_ocid
  name           = "${var.project_name}-terraform"
  description    = "Dynamic group for Terraform automation in WALFA"
  matching_rule  = "any {target.compartment.id = '${oci_identity_compartment.walfa.id}'}"
}

# ── IAM policy: manage everything in walfa compartment ──

resource "oci_identity_policy" "terraform_manage" {
  compartment_id = var.compartment_ocid
  name           = "${var.project_name}-terraform-manage"
  description    = "Allow Terraform dynamic group to manage WALFA resources"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.terraform.name} to manage all-resources in compartment id ${oci_identity_compartment.walfa.id}",
  ]
}

# ── Dynamic group for GitHub Actions OIDC ─────
# Managed by the IAM module in the environment stack (not here).
