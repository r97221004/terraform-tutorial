output "bucket_name" {
  description = "Name of the model-weights bucket."
  value       = google_storage_bucket.models.name
}

output "bucket_url" {
  description = "gs:// URL of the model-weights bucket, for training and serving jobs."
  value       = google_storage_bucket.models.url
}

output "labels" {
  description = "Labels applied to every resource."
  value       = local.labels
}

output "model_bucket_settings" {
  description = "The model_bucket variable after optional() defaults were filled in."
  value       = var.model_bucket
}
