locals {
  # Every API this guide uses from here on. Enabling an API is free;
  # you pay only for what you create with it.
  services = toset([
    "artifactregistry.googleapis.com", # container images
    "compute.googleapis.com",          # VPCs, VMs, GPUs
    "container.googleapis.com",        # GKE
    "iam.googleapis.com",              # service accounts
    "iamcredentials.googleapis.com",   # Workload Identity, impersonation
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
  ])
}

resource "google_project_service" "enabled" {
  for_each = local.services

  service = each.key

  # Leave the API enabled when this resource is destroyed. Other
  # configurations (and people) in the project may depend on it.
  disable_on_destroy = false
}

# A Docker repository for model-serving images.
resource "google_artifact_registry_repository" "images" {
  # Referring to the API's resource creates the dependency: Terraform enables
  # Artifact Registry first, then creates the repository.
  project = google_project_service.enabled["artifactregistry.googleapis.com"].project

  location      = var.region
  repository_id = "serving-images"
  description   = "Container images for model serving."
  format        = "DOCKER"

  # Delete untagged images after 30 days, so old builds don't pile up.
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s"
    }
  }
}

data "google_project" "this" {}
