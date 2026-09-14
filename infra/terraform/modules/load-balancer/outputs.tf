output "public_ip_id" {
  value = oci_core_public_ip.ingress.id
}

output "public_ip_address" {
  value = oci_core_public_ip.ingress.ip_address
}
