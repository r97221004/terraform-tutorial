variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Region for the Cloud Run service. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "message" {
  description = "Passed to the container as MESSAGE. Changing it creates a new revision."
  type        = string
  default     = "Hello from Terraform"
}

variable "revision" {
  description = "Name for the revision. null lets Cloud Run name each one; set it to route traffic by name."
  type        = string
  default     = null
}

variable "traffic" {
  description = "Percent of requests for each revision, by name. Empty sends everything to the latest revision."
  type        = map(number)
  default     = {}

  validation {
    # concat([0], …) keeps sum() from failing on an empty map.
    condition     = length(var.traffic) == 0 || sum(concat([0], values(var.traffic))) == 100
    error_message = "The traffic percents must add up to 100."
  }
}
