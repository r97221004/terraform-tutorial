variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Same region as the cluster, so reads stay local and free of egress charges."
  type        = string
  default     = "us-central1"
}

variable "namespace" {
  description = "Kubernetes namespace of the model server."
  type        = string
  default     = "ml-serving"
}

variable "ksa_name" {
  description = "Kubernetes service account of the model server."
  type        = string
  default     = "vllm"
}
