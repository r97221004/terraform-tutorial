variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Default region. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Deployment environment, used in labels."
  type        = string
  default     = "dev"
}

variable "team" {
  description = "Owning team, used in labels."
  type        = string
  default     = "ml-platform"
}

variable "cost_center" {
  description = "Cost center, used in labels so billing reports can be split by it."
  type        = string
  default     = "research"
}
