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
    tutorial   = "state-basics"
  }
}

resource "google_storage_bucket" "artifacts" {
  name     = "${var.project_id}-state-basics"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  labels = {
    component = "artifacts"
  }

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_object" "notes" {
  bucket  = google_storage_bucket.artifacts.name
  name    = "NOTES.txt"
  content = "Created by Terraform. Delete me by hand to see drift.\n"
}

output "bucket_name" {
  description = "Name of the artifacts bucket."
  value       = google_storage_bucket.artifacts.name
}
