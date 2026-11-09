output "url" {
  description = "The HTTP function's URL. Call it with an identity token."
  value       = google_cloudfunctions2_function.hello.url
}

output "upload_bucket" {
  description = "Upload a file here to trigger on-upload."
  value       = google_storage_bucket.uploads.name
}
