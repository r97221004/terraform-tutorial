locals {
  default_labels = {
    managed-by = "terraform"
    tutorial   = "registry-modules"
  }
}

provider "google" {
  project        = var.project_id
  region         = var.region
  default_labels = local.default_labels
}

# Configured identically: some resources inside the registry modules use it.
provider "google-beta" {
  project        = var.project_id
  region         = var.region
  default_labels = local.default_labels
}
