locals {
  # Every resource either provider creates gets these labels, on top of its own.
  default_labels = {
    managed-by = "terraform"
    tutorial   = "google-provider"
  }
}

# The default google provider: used by any google_* resource that doesn't say otherwise.
provider "google" {
  project        = var.project_id
  region         = var.region
  default_labels = local.default_labels
}

# A second configuration of the SAME provider, for another region.
# Resources opt in with `provider = google.dr`.
provider "google" {
  alias          = "dr"
  project        = var.project_id
  region         = var.dr_region
  default_labels = local.default_labels
}

# google-beta is a separate provider with preview features.
# Configure it the same way so resources behave the same whichever one they use.
provider "google-beta" {
  project        = var.project_id
  region         = var.region
  default_labels = local.default_labels
}
