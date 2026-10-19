# A small module under test: a model-weights bucket with environment rules.

locals {
  is_prod = var.environment == "prod"
}

resource "google_storage_bucket" "models" {
  project  = var.project_id
  name     = "${var.project_id}-models-${var.environment}"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = !local.is_prod

  soft_delete_policy {
    # prod keeps deleted weights for 7 days; other environments don't pay for it.
    retention_duration_seconds = local.is_prod ? 604800 : 0
  }

  labels = {
    environment = var.environment
    component   = "model-weights"
  }
}

resource "google_storage_bucket_iam_member" "readers" {
  for_each = var.readers

  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectViewer"
  member = each.key
}

# A check block: reported as a warning on every plan and apply, without
# stopping anything. Good for "this works, but it's probably a mistake".
check "weights_next_to_gpus" {
  assert {
    condition     = lower(var.region) == lower(var.gpu_region)
    error_message = "The models bucket (${var.region}) isn't in the GPUs' region (${var.gpu_region}): every model load will cross regions and pay egress."
  }
}
