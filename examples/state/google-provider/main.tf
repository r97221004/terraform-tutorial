# Uses the default google provider -> var.region.
resource "google_storage_bucket" "primary" {
  name     = "${var.project_id}-gp-primary"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

# Uses the aliased provider -> var.dr_region.
resource "google_storage_bucket" "dr" {
  provider = google.dr

  name     = "${var.project_id}-gp-dr"
  location = var.dr_region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

# Uses google-beta. This resource exists in both providers; switching
# `provider` is all it takes. Do this only for a feature that needs it.
resource "google_storage_bucket" "beta" {
  provider = google-beta

  name     = "${var.project_id}-gp-beta"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}
