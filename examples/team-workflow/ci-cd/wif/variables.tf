variable "project_id" {
  description = "The GCP project CI deploys into. Set via TF_VAR_project_id."
  type        = string
}

variable "github_repository" {
  description = "The only GitHub repository allowed to authenticate, as OWNER/REPO."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must look like OWNER/REPO."
  }
}

variable "github_repository_id" {
  description = "Immutable numeric ID of the GitHub repository. Get it with: gh api repos/OWNER/REPO --jq .id"
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must be the repository's numeric GitHub ID."
  }
}

variable "state_bucket" {
  description = "The Terraform state bucket from the Remote Backend chapter."
  type        = string
}
