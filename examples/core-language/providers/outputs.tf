output "server_name" {
  description = "The generated server name."
  value       = random_pet.server.id
}
