output "workload_identity_provider" {
  description = "Value for the workflow's WIF_PROVIDER variable."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "plan_service_account" {
  description = "Value for the workflow's PLAN_SA variable."
  value       = google_service_account.plan.email
}

output "apply_service_account" {
  description = "Value for the workflow's APPLY_SA variable."
  value       = google_service_account.apply.email
}
