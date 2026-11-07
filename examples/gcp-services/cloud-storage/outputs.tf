output "bucket_name" {
  description = "The bucket's name, for gcloud storage commands."
  value       = google_storage_bucket.data.name
}

output "bucket_url" {
  description = "The bucket's gs:// URL."
  value       = google_storage_bucket.data.url
}

output "objects" {
  description = "gs:// URLs of the objects Terraform manages."
  value = [
    "${google_storage_bucket.data.url}/${google_storage_bucket_object.readme.name}",
    "${google_storage_bucket.data.url}/${google_storage_bucket_object.pipeline_config.name}",
  ]
}
