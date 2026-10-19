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
  description = "Deployment environment. Becomes part of names and labels."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "team" {
  description = "Owning team, used as a label value."
  type        = string

  validation {
    # GCP label values: lowercase letters, digits, - and _, at most 63 characters.
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.team))
    error_message = "team must be 1-63 characters: lowercase letters, digits, - or _."
  }
}

variable "model_bucket" {
  description = "Settings for the model-weights bucket. Every field is optional."
  type = object({
    name_suffix          = optional(string, "models")
    storage_class        = optional(string, "STANDARD")
    versioning           = optional(bool, true)
    old_versions_to_keep = optional(number, 3)
  })
  default = {}

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.model_bucket.storage_class)
    error_message = "model_bucket.storage_class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}

variable "extra_labels" {
  description = "Additional labels to put on every resource."
  type        = map(string)
  default     = {}
}
