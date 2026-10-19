output "models_bucket" {
  description = "Upload model weights here."
  value       = google_storage_bucket.models.name
}

output "dockerhub_repository" {
  description = "Prefix for Docker Hub images pulled through the cache."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.dockerhub.repository_id}"
}

output "serving_repository" {
  description = "Push your own images here."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.serving.repository_id}"
}
