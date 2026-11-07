resource "google_project_service" "enabled" {
  for_each = toset([
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ])

  service            = each.value
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

resource "google_iam_workload_identity_pool_provider" "plan" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-plan"
  display_name                       = "GitHub Terraform plan"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Build a short, unique audit subject from immutable/run claims instead of
  # GitHub's default `sub`, whose format varies by repository creation date.
  attribute_mapping = {
    "google.subject"          = "assertion.repository_id + ':' + assertion.run_id"
    "attribute.access"        = "'plan'"
    "attribute.repository_id" = "assertion.repository_id"
    "attribute.workflow_ref"  = "assertion.workflow_ref"
  }

  # Only the two reviewed workflow paths in this exact repository may exchange
  # a token. PR plans are still read-only at both the project and state bucket.
  attribute_condition = <<-EOT
    assertion.repository_id == '${var.github_repository_id}' &&
    (assertion.workflow_ref.startsWith('${var.github_repository}/.github/workflows/terraform.yml@') ||
     assertion.workflow_ref.startsWith('${var.github_repository}/.github/workflows/drift.yml@')) &&
    (assertion.event_name == 'pull_request' ||
     (assertion.event_name == 'push' && assertion.ref == 'refs/heads/main') ||
     assertion.event_name == 'schedule' ||
     assertion.event_name == 'workflow_dispatch')
  EOT
}

resource "google_iam_workload_identity_pool_provider" "apply" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-apply"
  display_name                       = "GitHub Terraform apply"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"          = "assertion.repository_id + ':' + assertion.run_id"
    "attribute.access"        = "'apply'"
    "attribute.repository_id" = "assertion.repository_id"
    "attribute.workflow_ref"  = "assertion.workflow_ref"
  }

  # The apply provider accepts only the trusted workflow from main, after its
  # protected production environment has been approved. No `sub` parsing.
  attribute_condition = <<-EOT
    assertion.repository_id == '${var.github_repository_id}' &&
    assertion.workflow_ref == '${var.github_repository}/.github/workflows/terraform.yml@refs/heads/main' &&
    assertion.event_name == 'push' &&
    assertion.ref == 'refs/heads/main' &&
    assertion.environment == 'production'
  EOT
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

# Tokens accepted by the narrowly scoped plan provider may use the plan SA.
resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool_path}/attribute.access/plan"
}

# Only tokens accepted by the main + production apply provider may use apply.
resource "google_service_account_iam_member" "apply_wif" {
  service_account_id = google_service_account.apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool_path}/attribute.access/apply"
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
  role    = each.value
  member  = google_service_account.apply.member
}

# Plans run with -lock=false, so they only need to read the state object.
resource "google_storage_bucket_iam_member" "plan_state" {
  bucket = var.state_bucket
  role   = "roles/storage.objectViewer"
  member = google_service_account.plan.member
}

# Apply needs to create the lock and update state.
resource "google_storage_bucket_iam_member" "apply_state" {
  bucket = var.state_bucket
  role   = "roles/storage.objectUser"
  member = google_service_account.apply.member
}

# Earlier versions of this example granted both identities through one
# for_each resource. Moving the apply grant keeps an existing binding in place;
# a delete-and-create of the same member could otherwise remove it.
moved {
  from = google_storage_bucket_iam_member.state["apply"]
  to   = google_storage_bucket_iam_member.apply_state
}
