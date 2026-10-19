# STARTING POINT. Apply this first, then follow the chapter:
#   cp refactored/main.tf main.tf

# A poorly named resource: "bucket" says nothing about what it's for.
resource "google_storage_bucket" "bucket" {
  name     = "${var.project_id}-rf-datasets"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

# A bucket another team is taking over. We'll stop managing it here,
# without deleting it.
resource "google_storage_bucket" "handover" {
  name     = "${var.project_id}-rf-handover"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}
