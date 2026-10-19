variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Default region. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

# Only used by version.tf. Ephemeral: Terraform never writes it to state or
# to a saved plan. Pass it as TF_VAR_hf_token, never in a .tfvars file.
variable "hf_token" {
  description = "Hugging Face access token to store in Secret Manager."
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "hf_token_version" {
  description = "Bump to store a new value of hf_token. 0 means Terraform doesn't manage the value."
  type        = number
  default     = 0
}
