locals {
  # GCS charges early-deletion fees if objects are deleted before these ages.
  min_days = {
    STANDARD = 0
    NEARLINE = 30
    COLDLINE = 90
    ARCHIVE  = 365
  }
}

# for_each over a map: one bucket per entry, addressed by key,
# e.g. google_storage_bucket.dataset["raw"].
resource "google_storage_bucket" "dataset" {
  for_each = var.datasets

  name          = "${var.project_id}-ma-${each.key}"
  location      = var.region
  storage_class = each.value.storage_class

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  labels = {
    stage = each.key
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.retention_days == null ? [] : [each.value.retention_days]
    content {
      condition {
        age = lifecycle_rule.value
      }
      action {
        type = "Delete"
      }
    }
  }

  lifecycle {
    # Checked during plan, before anything is created or changed.
    precondition {
      condition     = coalesce(each.value.retention_days, 36500) >= local.min_days[each.value.storage_class]
      error_message = "Dataset \"${each.key}\": retention_days is shorter than the minimum storage duration of ${each.value.storage_class}, so every deletion would pay an early-deletion fee."
    }
  }
}

# count as an on/off switch: zero or one bucket.
resource "google_storage_bucket" "scratch" {
  count = var.enable_scratch ? 1 : 0

  name     = "${var.project_id}-ma-scratch"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
}

# for_each over a set of strings: each.key and each.value are the same string.
resource "google_storage_bucket_object" "model_card" {
  for_each = var.models

  bucket  = google_storage_bucket.dataset["curated"].name
  name    = "model-cards/${each.key}.md"
  content = "# ${each.key}\n\nEvaluation results go here.\n"
}

# A marker that downstream jobs wait for. Nothing in it refers to the model
# cards, so depends_on is the only way to say "write this one last".
resource "google_storage_bucket_object" "ready" {
  bucket  = google_storage_bucket.dataset["curated"].name
  name    = "model-cards/_READY"
  content = "ok"

  depends_on = [google_storage_bucket_object.model_card]
}
