output "project_number" {
  description = "The project number, used in service agent emails."
  value       = data.google_project.this.number
}

output "enabled_services" {
  description = "APIs this configuration keeps enabled."
  value       = sort([for s in google_project_service.enabled : s.service])
}

output "image_repository" {
  description = "Push images here: docker push <this>/<image>:<tag>"
  value       = google_artifact_registry_repository.images.registry_uri
}
