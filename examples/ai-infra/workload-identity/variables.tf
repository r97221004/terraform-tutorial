variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Default region. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "namespace" {
  description = "Kubernetes namespace of the workload."
  type        = string
  default     = "ml-serving"
}

variable "ksa_name" {
  description = "Kubernetes service account the workload runs as."
  type        = string
  default     = "vllm"
}
