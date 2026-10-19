output "buckets" {
  description = "Each bucket and the location it was created in."
  value = {
    primary = google_storage_bucket.primary.location
    dr      = google_storage_bucket.dr.location
    beta    = google_storage_bucket.beta.location
  }
}
