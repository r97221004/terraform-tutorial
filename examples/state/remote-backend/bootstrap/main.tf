# Creates the bucket that holds Terraform state for everything else.
# This configuration starts with LOCAL state (it can't store state in a bucket
# that doesn't exist yet), then migrates its own state into the bucket.

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
    purpose    = "terraform-state"
  }
}

resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Every write of a state file keeps the previous version, so a bad apply
  # or a corrupted state can be rolled back.
  versioning {
    enabled = true
  }

  # Keep the 10 most recent old versions of each state file; delete older ones.
  lifecycle_rule {
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # No force_destroy: GCS refuses to delete the bucket while it holds state.
  lifecycle {
    prevent_destroy = true
  }
}

output "state_bucket" {
  description = "Put this in backend.hcl as `bucket`."
  value       = google_storage_bucket.tfstate.name
}
