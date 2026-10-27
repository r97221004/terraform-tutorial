output "server_name" {
  description = "The generated server name."
  value       = random_pet.server.id
}

output "readme_path" {
  description = "Path of the generated README file."
  value       = local_file.readme.filename
}
