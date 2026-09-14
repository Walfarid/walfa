output "compartment_id" {
  description = "OCID of the WALFA compartment"
  value       = oci_identity_compartment.walfa.id
}

output "compartment_name" {
  description = "Name of the WALFA compartment"
  value       = oci_identity_compartment.walfa.name
}

output "object_storage_namespace" {
  description = "OCI Object Storage namespace for the tenancy"
  value       = data.oci_objectstorage_namespace.this.namespace
}

output "tfstate_bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = oci_objectstorage_bucket.tfstate.name
}

output "terraform_dynamic_group_id" {
  description = "OCID of the Terraform automation dynamic group"
  value       = oci_identity_dynamic_group.terraform.id
}
