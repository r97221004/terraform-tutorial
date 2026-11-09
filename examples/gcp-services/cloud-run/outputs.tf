output "url" {
  description = "The service's HTTPS URL."
  value       = google_cloud_run_v2_service.hello.uri
}

# Cloud Run works out the next three during apply, but the provider plans them
# as unchanged, so the saved outputs lag one apply behind. For current values,
# run terraform apply -refresh-only, or ask gcloud run services describe.

output "latest_revision" {
  description = "The newest ready revision; may lag one apply behind. It gets all traffic unless var.traffic says otherwise."
  value       = google_cloud_run_v2_service.hello.latest_ready_revision
}

output "traffic" {
  description = "Percent of requests each revision gets; may lag one apply behind."
  value       = { for t in google_cloud_run_v2_service.hello.traffic_statuses : (t.revision != "" ? t.revision : "latest") => t.percent }
}

output "tag_urls" {
  description = "A URL per revision in var.traffic, which reaches that revision whatever its percent; may lag one apply behind."
  value       = { for t in google_cloud_run_v2_service.hello.traffic_statuses : t.tag => t.uri if t.tag != "" }
}
