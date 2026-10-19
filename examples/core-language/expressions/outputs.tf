output "owner_label" {
  description = "var.owner normalized into a valid label value."
  value       = local.owner_label
}

output "model_names" {
  description = "Enabled models (for expression + splat)."
  value       = local.model_names
}

output "gpus_by_model" {
  description = "GPUs each enabled model needs."
  value       = local.gpus_by_model
}

output "total_gpus" {
  description = "Total GPUs across enabled models."
  value       = local.total_gpus
}

output "subnet_cidrs" {
  description = "One /20 per environment, carved out with cidrsubnet."
  value       = local.subnet_cidrs
}
