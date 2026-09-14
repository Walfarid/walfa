output "media_bucket_name" {
  value = oci_objectstorage_bucket.media.name
}

output "media_bucket_id" {
  value = oci_objectstorage_bucket.media.id
}

output "namespace" {
  value = data.oci_objectstorage_namespace.this.namespace
}
