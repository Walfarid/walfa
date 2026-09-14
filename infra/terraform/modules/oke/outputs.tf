output "cluster_id" {
  value = oci_containerengine_cluster.this.id
}

output "cluster_endpoint" {
  value = oci_containerengine_cluster.this.endpoints
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.this.id
}

output "cluster_name" {
  value = oci_containerengine_cluster.this.name
}

output "kubernetes_version" {
  value = oci_containerengine_cluster.this.kubernetes_version
}

output "selected_image_id" {
  value = local.image_id
}
