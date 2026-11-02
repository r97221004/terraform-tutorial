output "bucket" {
  description = "The bucket's name and the location it was created in."
  value = {
    name     = google_storage_bucket.example.name
    location = google_storage_bucket.example.location
  }
}
