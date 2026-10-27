output "config_name" {
  description = "Name of the serving config."
  value       = local.config_name
}

output "config_file" {
  description = "Path of the generated config file, for scripts that deploy it."
  value       = local_file.serving.filename
}

output "labels" {
  description = "Labels recorded in the config."
  value       = local.labels
}

output "serving_settings" {
  description = "The serving variable after optional() defaults were filled in."
  value       = var.serving
}
