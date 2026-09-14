output "cluster_id" {
  description = "OKE cluster OCID"
  value       = module.oke.cluster_id
}

output "cluster_endpoint" {
  description = "OKE cluster API endpoints"
  value       = module.oke.cluster_endpoint
}

output "cluster_name" {
  description = "OKE cluster name"
  value       = module.oke.cluster_name
}

output "kubernetes_version" {
  description = "Kubernetes version running on the cluster"
  value       = module.oke.kubernetes_version
}

output "node_pool_id" {
  description = "Node pool OCID"
  value       = module.oke.node_pool_id
}

output "selected_image_id" {
  description = "ARM64 OKE image ID selected for the node pool"
  value       = module.oke.selected_image_id
}

output "vcn_id" {
  description = "VCN OCID"
  value       = module.network.vcn_id
}

output "public_ip_address" {
  description = "Reserved public IP for ingress"
  value       = module.load_balancer.public_ip_address
}

output "public_ip_id" {
  description = "Reserved public IP OCID"
  value       = module.load_balancer.public_ip_id
}

output "media_bucket_name" {
  description = "Application media bucket name"
  value       = module.object_storage.media_bucket_name
}

output "media_bucket_id" {
  description = "Application media bucket OCID"
  value       = module.object_storage.media_bucket_id
}

output "object_storage_namespace" {
  description = "OCI Object Storage namespace"
  value       = module.object_storage.namespace
}

output "ocir_repositories" {
  description = "OCIR repository OCIDs"
  value       = module.ocir.repositories
}

output "kubeconfig_command" {
  description = "Command to generate kubeconfig"
  value       = "oci ce cluster create-kubeconfig --cluster-id ${module.oke.cluster_id} --file $HOME/.kube/walfa-prod --region ${var.region} --profile default"
}
