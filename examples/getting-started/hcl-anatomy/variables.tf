variable "team" {
  description = "Team that owns the server."
  type        = string
  default     = "ml-platform"
}

variable "environment" {
  description = "Deployment environment, such as dev or prod."
  type        = string
  default     = "dev"
}
