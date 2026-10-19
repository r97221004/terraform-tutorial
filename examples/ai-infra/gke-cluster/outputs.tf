output "cluster_name" {
  description = "Cluster name, for later chapters and gcloud."
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "Cluster location (a zone)."
  value       = module.gke.cluster_location
}

output "get_credentials" {
  description = "Run this to point kubectl at the cluster."
  value       = module.gke.get_credentials
}

output "node_service_account" {
  description = "Service account the nodes run as."
  value       = module.gke.node_service_account
}
