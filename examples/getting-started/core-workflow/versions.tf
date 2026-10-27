# Not part of the chapter's walkthrough: the chapter starts without this file,
# and Providers & Version Pinning explains it. Real configurations always
# declare their providers and versions like this.
terraform {
  required_version = ">= 1.10"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}
