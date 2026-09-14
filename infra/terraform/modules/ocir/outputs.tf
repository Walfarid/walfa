output "repositories" {
  description = "Map of repository name to OCID"
  value       = { for k, v in oci_artifacts_container_repository.services : k => v.id }
}

output "repository_urls" {
  description = "Map of repository name to display name (push path)"
  value       = { for k, v in oci_artifacts_container_repository.services : k => v.display_name }
}
