output "network_id" {
  description = "VPC ID, in projects/PROJECT/global/networks/NAME form."
  value       = google_compute_network.vpc.id
}

output "network_name" {
  description = "VPC name."
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "Subnet ID, in projects/PROJECT/regions/REGION/subnetworks/NAME form."
  value       = google_compute_subnetwork.gke.id
}

output "subnet_name" {
  description = "Subnet name."
  value       = google_compute_subnetwork.gke.name
}

output "pods_range_name" {
  description = "Secondary range name for GKE Pods (ip_allocation_policy.cluster_secondary_range_name)."
  value       = google_compute_subnetwork.gke.secondary_ip_range[0].range_name
}

output "services_range_name" {
  description = "Secondary range name for GKE Services (ip_allocation_policy.services_secondary_range_name)."
  value       = google_compute_subnetwork.gke.secondary_ip_range[1].range_name
}
