output "ksa_principal" {
  description = "The IAM principal for the workload's Kubernetes service account."
  value       = local.ksa_principal
}

output "namespace_principals" {
  description = "The IAM principal set for every Kubernetes service account in the namespace."
  value       = local.namespace_principals
}

output "test_object" {
  description = "Object the test Pod reads."
  value       = "gs://${google_storage_bucket.wi_test.name}/${google_storage_bucket_object.hello.name}"
}
