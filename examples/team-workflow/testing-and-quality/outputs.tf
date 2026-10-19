output "bucket_name" {
  description = "Name of the models bucket."
  value       = google_storage_bucket.models.name
}

output "reader_count" {
  description = "How many principals can read the weights."
  value       = length(google_storage_bucket_iam_member.readers)
}
