terraform {
  # Write-only arguments (secret_data_wo) need Terraform 1.11 or newer.
  required_version = ">= 1.11"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}
