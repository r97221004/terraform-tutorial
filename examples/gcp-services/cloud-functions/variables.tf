variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Region for the functions and the upload bucket. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}
