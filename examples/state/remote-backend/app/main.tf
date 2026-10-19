variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Default region. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    managed-by = "terraform"
    tutorial   = "remote-backend"
  }
}

resource "google_storage_bucket" "app" {
  name     = "${var.project_id}-remote-backend-app"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

output "bucket_name" {
  description = "Name of the app bucket."
  value       = google_storage_bucket.app.name
}
