variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Default region. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the VM. The free tier's e2-micro must be in us-central1, us-west1, or us-east1."
  type        = string
  default     = "us-central1-a"
}
