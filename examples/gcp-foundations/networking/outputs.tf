output "network" {
  description = "VPC name, for GKE's `network` argument."
  value       = google_compute_network.vpc.name
}

output "subnetwork" {
  description = "Subnet name, for GKE's `subnetwork` argument."
  value       = google_compute_subnetwork.gke.name
}

output "ip_plan" {
  description = "Every range in the VPC."
  value = {
    nodes    = local.nodes_cidr
    pods     = var.pods_cidr
    services = local.services_cidr
  }
}

output "gke_secondary_range_names" {
  description = "For GKE's ip_allocation_policy."
  value = {
    pods     = google_compute_subnetwork.gke.secondary_ip_range[0].range_name
    services = google_compute_subnetwork.gke.secondary_ip_range[1].range_name
  }
}
