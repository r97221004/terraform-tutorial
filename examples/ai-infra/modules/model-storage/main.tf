# ---------------------------------------------------------------------------
# Model weights: one regional bucket, read by the model server.
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "models" {
  project  = var.project_id
  name     = "${var.project_id}-models"
  location = var.region # same region as the GPUs

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true # weights can be downloaded again; fine for a lab

  # A real directory tree: faster listing and renames through GCS FUSE.
  hierarchical_namespace {
    enabled = true
  }

  # Weights are reproducible, so don't pay to keep deleted copies for 7 days.
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
  member = var.reader_principal
}

# ---------------------------------------------------------------------------
# Images: your own builds, and a pull-through cache of Docker Hub.
# ---------------------------------------------------------------------------

resource "google_artifact_registry_repository" "serving" {
  project       = var.project_id
  location      = var.region
  repository_id = "serving"
  description   = "Images built by this team."
  format        = "DOCKER"

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 days
    }
  }
}

# A remote repository: pulls from Docker Hub on first use and caches the
# image in your region. Nodes reach it through Private Google Access, so
# pulls don't go through Cloud NAT and don't hit Docker Hub's rate limits.
resource "google_artifact_registry_repository" "dockerhub" {
  project       = var.project_id
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

# Nodes pull images, so the node service account reads both repositories.
resource "google_artifact_registry_repository_iam_member" "nodes_pull" {
  for_each = {
    serving   = google_artifact_registry_repository.serving.name
    dockerhub = google_artifact_registry_repository.dockerhub.name
  }

  project    = var.project_id
  location   = var.region
  repository = each.value
  role       = "roles/artifactregistry.reader"
  member     = var.node_service_account_member
}
