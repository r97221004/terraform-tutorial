variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Bucket location. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "readers" {
  description = "Principals that may read objects, such as \"user:you@example.com\" or \"serviceAccount:...\"."
  type        = set(string)
  default     = []
}
