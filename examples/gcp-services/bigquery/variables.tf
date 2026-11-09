variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Where the dataset's data is stored. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}
