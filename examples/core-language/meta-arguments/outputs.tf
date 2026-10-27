output "dataset_manifests" {
  description = "Dataset stage => manifest path."
  value       = { for stage, f in local_file.dataset : stage => f.filename }
}

output "scratch_readme" {
  description = "The scratch README's path, or null when enable_scratch is false."
  value       = one(local_file.scratch[*].filename)
}

output "model_cards" {
  description = "Paths of the model cards."
  value       = [for f in local_file.model_card : f.filename]
}
