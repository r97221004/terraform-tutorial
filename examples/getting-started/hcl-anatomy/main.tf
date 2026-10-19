locals {
  bucket_name = "${var.project_id}-hcl-anatomy"

  common_labels = {
    managed-by = "terraform"
    tutorial   = "hcl-anatomy"
  }
}

resource "google_storage_bucket" "notes" {
  name     = local.bucket_name
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  # An ARGUMENT whose value is a map: note the `=`.
  labels = local.common_labels

  # A nested BLOCK: no `=`.
  versioning {
    enabled = true
  }
}

resource "google_storage_bucket_object" "readme" {
  # Referencing another resource's attribute creates an implicit dependency:
  # Terraform creates the bucket first, and destroys this object first.
  bucket = google_storage_bucket.notes.name
  name   = "README.txt"

  content = <<-EOT
    This bucket is managed by Terraform.
    Project: ${var.project_id}
    Region:  ${upper(var.region)}
  EOT
}
