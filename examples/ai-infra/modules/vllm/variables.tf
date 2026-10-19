variable "image_repository" {
  description = "Registry prefix for Docker Hub images, e.g. REGION-docker.pkg.dev/PROJECT/dockerhub."
  type        = string
}

variable "models_bucket" {
  description = "Bucket that holds the model weights."
  type        = string
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

variable "namespace" {
  description = "Namespace to deploy into."
  type        = string
  default     = "ml-serving"
}

variable "ksa_name" {
  description = "Kubernetes service account; must match the Workload Identity grant on the bucket."
  type        = string
  default     = "vllm"
}

variable "enable_ui" {
  description = "Install Open WebUI in front of vLLM."
  type        = bool
  default     = true
}
