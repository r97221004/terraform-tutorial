resource "google_project_service" "enabled" {
  for_each = toset(["iam.googleapis.com", "storage.googleapis.com"])

  service            = each.key
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# One service account per workload, each with only the access it needs.
# ---------------------------------------------------------------------------

resource "google_service_account" "trainer" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "model-trainer"
  display_name = "Model training jobs"
  description  = "Writes trained model weights to the models bucket."
}

resource "google_service_account" "server" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "model-server"
  display_name = "Model serving"
  description  = "Reads model weights from the models bucket. Nothing else."
}

resource "google_storage_bucket" "models" {
  project  = google_project_service.enabled["storage.googleapis.com"].project
  name     = "${var.project_id}-iam-models"
  location = var.region

  uniform_bucket_level_access = true # required for bucket-level IAM conditions
  public_access_prevention    = "enforced"
  force_destroy               = true
}

# ---------------------------------------------------------------------------
# Grants on the RESOURCE, not the project: these roles apply to this bucket
# only. _iam_member is additive: it never removes anyone else's access.
# ---------------------------------------------------------------------------

resource "google_storage_bucket_iam_member" "trainer_writes_models" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectUser" # read, create, overwrite, delete objects
  member = google_service_account.trainer.member
}

resource "google_storage_bucket_iam_member" "server_reads_models" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectViewer" # read only
  member = google_service_account.server.member
}

# Time-limited access: the grant stops working at the given time.
resource "google_storage_bucket_iam_member" "temporary_readers" {
  for_each = var.temporary_readers

  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectViewer"
  member = each.key

  condition {
    title       = "expires-${substr(each.value, 0, 10)}"
    description = "Temporary read access."
    expression  = "request.time < timestamp(\"${each.value}\")"
  }
}

# ---------------------------------------------------------------------------
# Project-level grants, only for things that have no narrower scope:
# both workloads write logs and metrics.
# ---------------------------------------------------------------------------

locals {
  workload_members = {
    trainer = google_service_account.trainer.member
    server  = google_service_account.server.member
  }
  project_roles = ["roles/logging.logWriter", "roles/monitoring.metricWriter"]

  # Every (workload, role) pair, keyed like "server/roles/logging.logWriter".
  project_grants = {
    for pair in setproduct(keys(local.workload_members), local.project_roles) :
    "${pair[0]}/${pair[1]}" => { member = local.workload_members[pair[0]], role = pair[1] }
  }
}

resource "google_project_iam_member" "workloads" {
  for_each = local.project_grants

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}
