locals {
  # Every resource this provider creates gets these labels, on top of its own.
  default_labels = {
    managed-by = "terraform"
    tutorial   = "google-provider"
  }
}

provider "google" {
  project        = var.project_id
  region         = var.region
  default_labels = local.default_labels
}
