output "compartment_id" {
  value = var.compartment_id
}

output "compartment_name" {
  value = data.oci_identity_compartment.this.name
}
