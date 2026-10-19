# Unit tests: plan only, against a mocked provider. No credentials, no
# cloud resources, runs in seconds. `terraform test` runs every *.tftest.hcl.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "us-central1"
  gpu_region = "us-central1"
}

run "dev_bucket_is_disposable" {
  command = plan

  variables {
    environment = "dev"
  }

  assert {
    condition     = google_storage_bucket.models.name == "test-project-models-dev"
    error_message = "Bucket name should follow <project>-models-<environment>."
  }

  assert {
    condition     = google_storage_bucket.models.force_destroy == true
    error_message = "dev buckets should be deletable with their contents."
  }

  assert {
    condition     = google_storage_bucket.models.soft_delete_policy[0].retention_duration_seconds == 0
    error_message = "dev buckets shouldn't pay for soft delete."
  }
}

run "prod_bucket_is_protected" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = google_storage_bucket.models.force_destroy == false
    error_message = "prod buckets must never be force-destroyed."
  }

  assert {
    condition     = google_storage_bucket.models.soft_delete_policy[0].retention_duration_seconds == 604800
    error_message = "prod buckets must keep deleted objects for 7 days."
  }
}

run "readers_get_one_grant_each" {
  command = plan

  variables {
    environment = "dev"
    readers     = ["user:a@example.com", "group:ml@example.com"]
  }

  assert {
    condition     = output.reader_count == 2
    error_message = "Each reader should get exactly one grant."
  }

  assert {
    condition     = google_storage_bucket_iam_member.readers["group:ml@example.com"].role == "roles/storage.objectViewer"
    error_message = "Readers must only get objectViewer."
  }
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  # The test passes only if this validation fails.
  expect_failures = [var.environment]
}
