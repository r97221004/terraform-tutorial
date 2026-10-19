variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Default region. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "temporary_readers" {
  description = <<-EOT
    Principals who may read the model bucket until a given time, e.g.
    { "user:alice@example.com" = "2026-12-31T00:00:00Z" }.
  EOT
  type        = map(string)
  default     = {}
}
