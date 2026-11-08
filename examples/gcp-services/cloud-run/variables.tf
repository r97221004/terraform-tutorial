variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Region for the Cloud Run service. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "message" {
  description = "Passed to the container as MESSAGE. Changing it creates a new revision."
  type        = string
  default     = "Hello from Terraform"
}
