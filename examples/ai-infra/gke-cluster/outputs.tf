output "cluster_name" {
  description = "Cluster name, for later chapters and gcloud."
  value       = google_container_cluster.ml.name
}

output "cluster_location" {
  description = "Cluster location (a zone)."
  value       = google_container_cluster.ml.location
}

output "get_credentials" {
  description = "Run this to point kubectl at the cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.ml.name} --location ${google_container_cluster.ml.location} --dns-endpoint"
}

output "node_service_account" {
  description = "Service account the nodes run as."
  value       = google_service_account.nodes.email
}
