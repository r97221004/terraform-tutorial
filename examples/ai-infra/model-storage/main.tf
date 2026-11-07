resource "google_project_service" "enabled" {
  for_each = toset(["storage.googleapis.com", "artifactregistry.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

data "google_project" "this" {}

locals {
  vllm_principal = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${var.namespace}/sa/${var.ksa_name}"
}

# The models bucket and both image repositories, from the shared module.
module "storage" {
  source = "../modules/model-storage"

  project_id                  = var.project_id
  region                      = var.region
  reader_principal            = local.vllm_principal
  node_service_account_member = "serviceAccount:gke-nodes@${var.project_id}.iam.gserviceaccount.com" # GKE Cluster chapter

  depends_on = [google_project_service.enabled]
}
