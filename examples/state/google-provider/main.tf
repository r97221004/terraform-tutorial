resource "google_storage_bucket" "example" {
  name     = "${var.project_id}-gp-example"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}
