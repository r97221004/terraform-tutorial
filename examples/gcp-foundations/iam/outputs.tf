output "trainer_email" {
  description = "Run training jobs as this service account."
  value       = google_service_account.trainer.email
}

output "server_email" {
  description = "Run model servers as this service account."
  value       = google_service_account.server.email
}

output "models_bucket" {
  description = "The bucket both workloads use."
  value       = google_storage_bucket.models.url
}
