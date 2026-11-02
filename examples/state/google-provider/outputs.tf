output "bucket_url" {
  description = "The bucket's gs:// URL."
  value       = google_storage_bucket.first.url
}
