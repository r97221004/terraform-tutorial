output "project_number" {
  description = "From the google_project data source."
  value       = data.google_project.this.number
}

output "running_as" {
  description = "The account Terraform is authenticated as."
  value       = data.google_client_openid_userinfo.me.email
}

output "gcs_service_agent" {
  description = "Cloud Storage's service agent for this project."
  value       = data.google_storage_project_service_account.gcs.email_address
}

output "bucket_url" {
  description = "Computed by GCP, known only after apply."
  value       = google_storage_bucket.datasets.url
}

output "bucket_self_link" {
  description = "Computed by GCP, known only after apply."
  value       = google_storage_bucket.datasets.self_link
}
