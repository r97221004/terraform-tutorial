output "models_bucket" {
  description = "Upload model weights here."
  value       = google_storage_bucket.models.name
}

output "vllm_image" {
  description = "The vLLM image, pulled through the Docker Hub cache."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.dockerhub.repository_id}/vllm/vllm-openai:v0.31.0"
}

output "serving_repository" {
  description = "Push your own images here."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.serving.repository_id}"
}
