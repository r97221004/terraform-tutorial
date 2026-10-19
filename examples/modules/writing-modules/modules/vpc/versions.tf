terraform {
  required_version = ">= 1.10"

  # A reusable module states a MINIMUM provider version and nothing else.
  # The root module that calls it picks the exact version.
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
  }
}
