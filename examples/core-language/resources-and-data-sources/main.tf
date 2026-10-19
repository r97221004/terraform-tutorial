# Resources are things Terraform MANAGES: it creates, updates, and deletes them.

resource "google_storage_bucket" "datasets" {
  # Required arguments.
  name     = "${var.project_id}-datasets"
  location = var.region

  # Optional arguments. Leave one out and the provider or GCP picks a default.
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  versioning {
    enabled = true
  }

  # Keep only the 3 newest old versions of each object.
  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}

# Data source attributes feed into a resource like any other value.
resource "google_storage_bucket_object" "manifest" {
  bucket       = google_storage_bucket.datasets.name
  name         = "MANIFEST.json"
  content_type = "application/json"

  content = jsonencode({
    project_id     = data.google_project.this.project_id
    project_number = data.google_project.this.number
    created_by     = data.google_client_openid_userinfo.me.email
  })
}
