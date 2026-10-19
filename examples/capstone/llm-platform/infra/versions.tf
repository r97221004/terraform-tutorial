terraform {
  required_version = ">= 1.10"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }

  # terraform init -backend-config=backend.hcl   (prefix = "capstone/infra")
  backend "gcs" {}
}
