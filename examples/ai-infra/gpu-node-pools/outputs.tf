output "gpu_pool" {
  description = "Name of the GPU node pool."
  value       = module.gpu_pool.name
}

output "cluster_dns_endpoint" {
  description = "Read from the existing cluster by the data source."
  value       = data.google_container_cluster.ml.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}
