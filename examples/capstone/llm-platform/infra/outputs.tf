output "cluster_name" {
  description = "For ../app and kubectl."
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "For ../app and kubectl."
  value       = module.gke.cluster_location
}

output "models_bucket" {
  description = "Upload the model weights here."
  value       = module.storage.models_bucket
}

output "get_credentials" {
  description = "Point kubectl at the cluster."
  value       = module.gke.get_credentials
}
