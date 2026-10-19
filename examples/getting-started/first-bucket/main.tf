terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}

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
}

resource "google_storage_bucket" "first" {
  # Bucket names are globally unique across ALL of GCP, so prefix with the project ID.
  name     = "${var.project_id}-first-bucket"
  location = var.region

  uniform_bucket_level_access = true       # IAM only, no per-object ACLs
  public_access_prevention    = "enforced" # can never be made public by accident

  # Lets `terraform destroy` delete the bucket even if it still holds objects.
  # Fine for a lab; leave it off for buckets holding data you care about.
  force_destroy = true

  labels = {
    managed-by = "terraform"
    tutorial   = "core-workflow"
  }
}

output "bucket_url" {
  description = "The gs:// URL of the bucket."
  value       = google_storage_bucket.first.url
}
