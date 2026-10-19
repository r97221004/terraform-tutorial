output "secret_id" {
  description = "Full resource name of the secret. Workloads read projects/.../secrets/hf-token/versions/latest."
  value       = google_secret_manager_secret.hf_token.id
}

output "downloader_email" {
  description = "Run the download job as this service account."
  value       = google_service_account.downloader.email
}
