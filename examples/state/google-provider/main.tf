provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "first" {
  name     = "${var.project_id}-first-bucket"
  location = var.region

  # Let `terraform destroy` delete the bucket even if it still holds objects.
  force_destroy = true
}
