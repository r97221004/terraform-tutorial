resource "google_project_service" "enabled" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

data "google_project" "this" {}

# ---------------------------------------------------------------------------
# Trust GitHub's OIDC tokens, but only from one repository.
# ---------------------------------------------------------------------------

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project_service.enabled["sts.googleapis.com"].project
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Claims from GitHub's token, copied into attributes IAM can match on.
  attribute_mapping = {
    "google.subject"         = "assertion.sub"
    "attribute.repository"   = "assertion.repository"
    "attribute.ref"          = "assertion.ref"
    "attribute.workflow_ref" = "assertion.job_workflow_ref"
  }

  # Without this, ANY repository on GitHub could exchange its token here.
  attribute_condition = "assertion.repository == '${var.github_repository}'"
}

locals {
  pool_path = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}"
}

# ---------------------------------------------------------------------------
# Two identities: plan (any branch or PR, read-only) and apply (production
# environment only, after approval).
# ---------------------------------------------------------------------------

resource "google_service_account" "plan" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "terraform-plan"
  display_name = "Terraform plan (CI)"
}

resource "google_service_account" "apply" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "terraform-apply"
  display_name = "Terraform apply (CI)"
}

# Any workflow in the repository may act as the plan identity...
resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool_path}/attribute.repository/${var.github_repository}"
}

# ...but only jobs running in the "production" GitHub environment, which
# requires a reviewer's approval, may act as the apply identity. GitHub sets
# the token's subject to repo:OWNER/REPO:environment:NAME for such jobs.
resource "google_service_account_iam_member" "apply_wif" {
  service_account_id = google_service_account.apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${local.pool_path}/subject/repo:${var.github_repository}:environment:production"
}

# Plan reads everything; it never changes anything in the project.
resource "google_project_iam_member" "plan_viewer" {
  project = var.project_id
  role    = "roles/viewer"
  member  = google_service_account.plan.member
}

# Apply changes resources. Editor is broad; narrow it to the roles your
# configurations actually need once you know them.
resource "google_project_iam_member" "apply_editor" {
  for_each = toset([
    "roles/editor",
    "roles/resourcemanager.projectIamAdmin", # Terraform manages IAM grants
  ])

  project = var.project_id
  role    = each.key
  member  = google_service_account.apply.member
}

# Both read and lock state; only on the state bucket.
resource "google_storage_bucket_iam_member" "state" {
  for_each = {
    plan  = google_service_account.plan.member
    apply = google_service_account.apply.member
  }

  bucket = var.state_bucket
  role   = "roles/storage.objectUser"
  member = each.value
}
