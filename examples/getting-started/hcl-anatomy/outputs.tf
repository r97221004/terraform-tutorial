output "bucket_name" {
  description = "Name of the notes bucket."
  value       = google_storage_bucket.notes.name
}

output "readme_uri" {
  description = "gs:// URI of the uploaded README object."
  value       = "gs://${google_storage_bucket.notes.name}/${google_storage_bucket_object.readme.name}"
}
