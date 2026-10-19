data "google_project" "this" {}

locals {
  workload_pool = "${var.project_id}.svc.id.goog"
  pool_path     = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${local.workload_pool}"

  # One Kubernetes service account, as an IAM principal.
  ksa_principal = "principal://iam.googleapis.com/${local.pool_path}/subject/ns/${var.namespace}/sa/${var.ksa_name}"

  # Every service account in the namespace, as an IAM principal set.
  namespace_principals = "principalSet://iam.googleapis.com/${local.pool_path}/namespace/${var.namespace}"
}

# Something for the Pod to read, to prove access works.
resource "google_storage_bucket" "wi_test" {
  name     = "${var.project_id}-wi-test"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true
}

resource "google_storage_bucket_object" "hello" {
  bucket  = google_storage_bucket.wi_test.name
  name    = "hello.txt"
  content = "Read by a Pod with no keys.\n"
}

# The grant: the Kubernetes service account, directly, on this bucket.
# No Google service account in between.
resource "google_storage_bucket_iam_member" "ksa_reads" {
  bucket = google_storage_bucket.wi_test.name
  role   = "roles/storage.objectViewer"
  member = local.ksa_principal
}
