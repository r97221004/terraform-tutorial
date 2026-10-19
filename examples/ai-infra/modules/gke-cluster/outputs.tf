output "cluster_id" {
  description = "Cluster ID, for node pools."
  value       = google_container_cluster.ml.id
}

output "cluster_name" {
  description = "Cluster name."
  value       = google_container_cluster.ml.name
}

output "cluster_location" {
  description = "Cluster location (a zone)."
  value       = google_container_cluster.ml.location
}

output "dns_endpoint" {
  description = "The control plane's DNS endpoint, for kubectl and the kubernetes provider."
  value       = google_container_cluster.ml.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}

output "node_service_account" {
  description = "Email of the service account the nodes run as."
  value       = google_service_account.nodes.email
}

output "node_service_account_member" {
  description = "The node service account as an IAM member string."
  value       = google_service_account.nodes.member
}

output "get_credentials" {
  description = "Run this to point kubectl at the cluster."
  value       = "gcloud container clusters get-credentials ${google_container_cluster.ml.name} --location ${google_container_cluster.ml.location} --project ${var.project_id} --dns-endpoint"
}
