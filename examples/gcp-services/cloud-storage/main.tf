# A bucket for raw data that gets cheaper as it ages, plus the two small
# objects Terraform manages in it. The data itself goes in with gcloud.

resource "google_storage_bucket" "data" {
  name          = "${var.project_id}-data"
  location      = var.region # can't be changed later: a new location is a new bucket
  storage_class = "STANDARD" # the default class for new objects

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Lab only: lets `terraform destroy` delete the bucket with objects in it.
  force_destroy = true

  # Overwriting or deleting an object keeps the old version as noncurrent.
  versioning {
    enabled = true
  }

  # Standard for the first 30 days, then Nearline, then Coldline, then gone.
  lifecycle_rule {
    condition {
      age                   = 30
      matches_storage_class = ["STANDARD"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age                   = 90
      matches_storage_class = ["NEARLINE"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }

  # Old versions: keep 3 per object, and none longer than 30 days.
  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    component = "raw-data"
  }
}

# Small, rarely changing files belong in Terraform. Data doesn't.
resource "google_storage_bucket_object" "readme" {
  bucket       = google_storage_bucket.data.name
  name         = "README.txt"
  source       = "${path.module}/files/README.txt"
  content_type = "text/plain"
}

resource "google_storage_bucket_object" "pipeline_config" {
  bucket = google_storage_bucket.data.name
  name   = "config/pipeline.json"
  content = jsonencode({
    input_prefix = "raw/"
    format       = "csv"
  })
  content_type = "application/json"
}

resource "google_storage_bucket_iam_member" "readers" {
  for_each = var.readers

  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectViewer"
  member = each.value
}
