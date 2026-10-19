terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  # Partial configuration: the bucket and prefix come from backend.hcl,
  # passed with `terraform init -backend-config=backend.hcl`.
  backend "gcs" {}
}
