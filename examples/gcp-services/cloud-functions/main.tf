# Two functions from one folder of Python source: one answers HTTP requests,
# the other runs whenever a file lands in the uploads bucket.

resource "google_project_service" "enabled" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",       # builds the source into an image
    "artifactregistry.googleapis.com", # stores that image
    "run.googleapis.com",              # runs it
    "eventarc.googleapis.com",         # delivers the upload events
    "pubsub.googleapis.com",           # carries them
    "iam.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# The source: zip the src folder and upload the zip.

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/out/function.zip"
}

resource "google_storage_bucket" "source" {
  name     = "${var.project_id}-gcf-source"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

# The zip's hash is in the object name, so changing the code uploads a new
# object, and the functions that point at it rebuild.
resource "google_storage_bucket_object" "source" {
  name   = "function-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.source.output_path
}

# Both functions run as this account. It needs no roles to answer HTTP.
resource "google_service_account" "function" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "hello-function"
  display_name = "Cloud Functions chapter"
}

# ---------------------------------------------------------------------------
# An HTTP function. Private: only callers with the invoker role can reach it.

resource "google_cloudfunctions2_function" "hello" {
  project  = google_project_service.enabled["cloudfunctions.googleapis.com"].project
  name     = "hello-http"
  location = var.region

  # How to build it: runtime, the Python function to call, and the source.
  build_config {
    runtime     = "python312"
    entry_point = "hello_http"

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  # How to run it.
  service_config {
    service_account_email = google_service_account.function.email
    available_memory      = "256M"
    max_instance_count    = 2 # a ceiling on cost
    timeout_seconds       = 60
  }
}

# ---------------------------------------------------------------------------
# An event function: runs once for every file uploaded to this bucket.

resource "google_storage_bucket" "uploads" {
  name     = "${var.project_id}-gcf-uploads"
  location = var.region # an event trigger must be in the bucket's region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

# Cloud Storage publishes the upload events, through Pub/Sub.
data "google_storage_project_service_account" "gcs" {}

resource "google_project_iam_member" "gcs_publishes_events" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}

# Eventarc receives each event as the function's account...
resource "google_project_iam_member" "function_receives_events" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = google_service_account.function.member
}

resource "google_cloudfunctions2_function" "on_upload" {
  project  = google_project_service.enabled["cloudfunctions.googleapis.com"].project
  name     = "on-upload"
  location = var.region

  build_config {
    runtime     = "python312"
    entry_point = "on_upload"

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.source.name
      }
    }
  }

  service_config {
    service_account_email = google_service_account.function.email
    available_memory      = "256M"
    max_instance_count    = 2
    timeout_seconds       = 60
  }

  event_trigger {
    trigger_region        = var.region
    event_type            = "google.cloud.storage.object.v1.finalized" # a new file
    retry_policy          = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = google_service_account.function.email

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.uploads.name
    }
  }

  depends_on = [
    google_project_iam_member.gcs_publishes_events,
    google_project_iam_member.function_receives_events,
  ]
}

# ...and calls the function with it, so that account needs the invoker role
# on the function's Cloud Run service, which has the function's name.
resource "google_cloud_run_v2_service_iam_member" "events_invoke" {
  project  = google_cloudfunctions2_function.on_upload.project
  location = google_cloudfunctions2_function.on_upload.location
  name     = google_cloudfunctions2_function.on_upload.name
  role     = "roles/run.invoker"
  member   = google_service_account.function.member
}
