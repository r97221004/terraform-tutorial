# --- Model weights and images (Model Storage, Workload Identity) ------------

locals {
  vllm_principal = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${local.namespace}/sa/${local.ksa_name}"
}

resource "google_storage_bucket" "models" {
  project  = google_project_service.enabled["storage.googleapis.com"].project
  name     = "${var.project_id}-models"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  hierarchical_namespace {
    enabled = true
  }

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  labels = {
    component = "model-weights"
  }
}

resource "google_storage_bucket_iam_member" "vllm_reads_models" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectViewer"
  member = local.vllm_principal
}

resource "google_artifact_registry_repository" "dockerhub" {
  project       = google_project_service.enabled["artifactregistry.googleapis.com"].project
  location      = var.region
  repository_id = "dockerhub"
  description   = "Pull-through cache of Docker Hub."
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }
}

resource "google_artifact_registry_repository_iam_member" "nodes_pull" {
  location   = var.region
  repository = google_artifact_registry_repository.dockerhub.name
  role       = "roles/artifactregistry.reader"
  member     = google_service_account.nodes.member
}
