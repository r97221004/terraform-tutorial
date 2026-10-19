output "dataset_buckets" {
  description = "Dataset stage => bucket name."
  value       = { for stage, b in google_storage_bucket.dataset : stage => b.name }
}

output "scratch_bucket" {
  description = "The scratch bucket's name, or null when enable_scratch is false."
  value       = one(google_storage_bucket.scratch[*].name)
}

output "model_cards" {
  description = "gs:// paths of the model cards."
  value       = [for o in google_storage_bucket_object.model_card : "gs://${o.bucket}/${o.name}"]
}
