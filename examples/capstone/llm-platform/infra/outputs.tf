output "cluster_name" {
  description = "For ../app and kubectl."
  value       = google_container_cluster.ml.name
}

output "cluster_location" {
  description = "For ../app and kubectl."
  value       = google_container_cluster.ml.location
}

output "models_bucket" {
  description = "Upload the model weights here."
  value       = google_storage_bucket.models.name
}

output "get_credentials" {
  description = "Point kubectl at the cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.ml.name} --location ${google_container_cluster.ml.location} --dns-endpoint"
}
