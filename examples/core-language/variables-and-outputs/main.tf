locals {
  # Name things once, use the names everywhere.
  name_prefix = "${var.project_id}-${var.environment}"
  bucket_name = "${local.name_prefix}-${var.model_bucket.name_suffix}"

  # Labels every resource gets (applied through the provider's default_labels).
  # Keys in extra_labels can't override these, because these come last.
  labels = merge(var.extra_labels, {
    environment = var.environment
    team        = var.team
    managed-by  = "terraform"
  })
}

resource "google_storage_bucket" "models" {
  name          = local.bucket_name
  location      = var.region
  storage_class = var.model_bucket.storage_class

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  versioning {
    enabled = var.model_bucket.versioning
  }

  lifecycle_rule {
    condition {
      num_newer_versions = var.model_bucket.old_versions_to_keep
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}
