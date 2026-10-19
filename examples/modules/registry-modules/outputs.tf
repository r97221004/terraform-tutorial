output "network_name" {
  description = "VPC name."
  value       = module.vpc.network_name
}

output "subnet_secondary_ranges" {
  description = "Secondary ranges per subnet, as reported by the module."
  value       = module.vpc.subnets_secondary_ranges
}
