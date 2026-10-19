output "name" {
  description = "Name of the GPU node pool."
  value       = google_container_node_pool.l4_spot.name
}
