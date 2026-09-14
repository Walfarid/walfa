output "vcn_id" {
  value = oci_core_vcn.this.id
}

output "lb_subnet_id" {
  value = oci_core_subnet.lb.id
}

output "worker_subnet_id" {
  value = oci_core_subnet.worker.id
}

output "api_subnet_id" {
  value = oci_core_subnet.api.id
}

output "cluster_nsg_id" {
  value = oci_core_network_security_group.cluster.id
}

output "worker_nsg_id" {
  value = oci_core_network_security_group.worker.id
}

output "api_nsg_id" {
  value = oci_core_network_security_group.api.id
}

output "lb_nsg_id" {
  value = oci_core_network_security_group.lb.id
}

output "vcn_cidr_blocks" {
  value = oci_core_vcn.this.cidr_blocks
}
