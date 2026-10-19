variable "project_id" {
  description = "Project to create the bucket in."
  type        = string
}

variable "environment" {
  description = "dev, staging, or prod. prod keeps deleted objects for 7 days."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "region" {
  description = "Bucket location. Must match the region of the GPUs that read it."
  type        = string
}

variable "gpu_region" {
  description = "Region of the GPU node pool that reads the weights."
  type        = string
}

variable "readers" {
  description = "IAM principals that may read the weights."
  type        = set(string)
  default     = []
}
