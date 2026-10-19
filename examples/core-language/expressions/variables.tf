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
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Free-form owner name. Normalized into a valid label value."
  type        = string
  default     = "ML Platform Team"
}

variable "models" {
  description = "Models to serve. Rendered into the serving config."
  type = list(object({
    name    = string
    repo    = string
    gpus    = optional(number, 1)
    enabled = optional(bool, true)
  }))
  default = [
    { name = "llama-3-1-8b", repo = "meta-llama/Llama-3.1-8B-Instruct" },
    { name = "qwen2-5-7b", repo = "Qwen/Qwen2.5-7B-Instruct" },
    { name = "mixtral-8x7b", repo = "mistralai/Mixtral-8x7B-Instruct-v0.1", gpus = 4, enabled = false },
  ]
}

variable "storage_tiers" {
  description = "Move objects to a cheaper storage class after this many days."
  type        = map(number)
  default = {
    NEARLINE = 30
    COLDLINE = 90
  }
}

variable "cors_origins" {
  description = "Browser origins allowed to read the bucket directly. Empty means no CORS rule."
  type        = list(string)
  default     = []
}
