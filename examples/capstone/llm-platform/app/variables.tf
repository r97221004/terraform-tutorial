variable "project_id" {
  description = "The GCP project. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Region of the cluster and the Artifact Registry repositories. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone of the (zonal) cluster."
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "The cluster from the GKE Cluster chapter."
  type        = string
  default     = "ml-gke"
}

variable "model" {
  description = "Directory of the model inside the models bucket."
  type        = string
  default     = "Qwen2.5-1.5B-Instruct"
}

variable "vllm_version" {
  description = "vLLM image tag. Pin it; don't use latest."
  type        = string
  default     = "v0.31.0"
}

variable "enable_ui" {
  description = "Install Open WebUI in front of vLLM."
  type        = bool
  default     = true
}
