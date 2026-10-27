variable "environment" {
  description = "Deployment environment. Becomes part of names and labels."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "team" {
  description = "Owning team, used in names and as a label value."
  type        = string

  validation {
    # The same rule GCP applies to label values: lowercase letters, digits, - and _, at most 63 characters.
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.team))
    error_message = "team must be 1-63 characters: lowercase letters, digits, - or _."
  }
}

variable "serving" {
  description = "Settings for the model-serving config. Every field is optional."
  type = object({
    name_suffix = optional(string, "serving")
    gpu_type    = optional(string, "nvidia-l4")
    replicas    = optional(number, 1)
    max_tokens  = optional(number, 4096)
  })
  default = {}

  validation {
    condition     = contains(["nvidia-l4", "nvidia-a100-80gb", "nvidia-h100-80gb"], var.serving.gpu_type)
    error_message = "serving.gpu_type must be nvidia-l4, nvidia-a100-80gb, or nvidia-h100-80gb."
  }
}

variable "extra_labels" {
  description = "Additional labels to record in the config."
  type        = map(string)
  default     = {}
}
