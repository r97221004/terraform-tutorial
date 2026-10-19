# AFTER REFACTORING. Copy over ../main.tf, then run terraform plan.

# 1. RENAME: google_storage_bucket.bucket -> google_storage_bucket.datasets.
#    Without the moved block, Terraform would destroy the old bucket and
#    create a new, empty one.
resource "google_storage_bucket" "datasets" {
  name     = "${var.project_id}-rf-datasets"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

moved {
  from = google_storage_bucket.bucket
  to   = google_storage_bucket.datasets
}

# 2. IMPORT: adopt a bucket that was created by hand with gcloud.
#    The import block says which real object; the resource block describes it.
import {
  to = google_storage_bucket.legacy_models
  id = "${var.project_id}-rf-legacy-models"
}

resource "google_storage_bucket" "legacy_models" {
  name     = "${var.project_id}-rf-legacy-models"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  labels = {
    owner = "research"
  }
}

# 3. REMOVE: stop managing the handover bucket, but leave it running.
#    The resource block is deleted; this block replaces it.
removed {
  from = google_storage_bucket.handover

  lifecycle {
    destroy = false
  }
}
