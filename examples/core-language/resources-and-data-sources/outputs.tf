output "owner" {
  description = "Read from the data source, so known at plan time."
  value       = local.team.owner
}

output "dataset_name" {
  description = "Generated at apply time."
  value       = random_pet.dataset.id
}

output "manifest_sha256" {
  description = "Computed by the provider, known only after apply."
  value       = local_file.manifest.content_sha256
}
