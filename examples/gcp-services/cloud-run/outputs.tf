output "url" {
  description = "The service's HTTPS URL."
  value       = google_cloud_run_v2_service.hello.uri
}

output "latest_revision" {
  description = "The revision currently serving all traffic."
  value       = google_cloud_run_v2_service.hello.latest_ready_revision
}
