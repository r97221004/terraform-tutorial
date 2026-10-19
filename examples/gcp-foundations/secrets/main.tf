resource "google_project_service" "enabled" {
  for_each = toset(["iam.googleapis.com", "secretmanager.googleapis.com"])

  service            = each.key
  disable_on_destroy = false
}

# The workload that needs the secret: it downloads gated model weights
# from Hugging Face.
resource "google_service_account" "downloader" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "model-downloader"
  display_name = "Model downloader"
  description  = "Downloads model weights from Hugging Face using the hf-token secret."
}

# The secret is a container. Terraform manages its name, replication,
# labels, and who can read it, but not (by default) its value.
resource "google_secret_manager_secret" "hf_token" {
  project   = google_project_service.enabled["secretmanager.googleapis.com"].project
  secret_id = "hf-token"

  replication {
    auto {}
  }
}

# Only the downloader can read the value. Granted on the secret, not the project.
resource "google_secret_manager_secret_iam_member" "downloader_reads_hf_token" {
  secret_id = google_secret_manager_secret.hf_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.downloader.member
}
