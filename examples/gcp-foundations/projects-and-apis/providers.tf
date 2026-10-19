locals {
  # The labeling convention: every resource carries these, through default_labels.
  labels = {
    environment = var.environment
    team        = var.team
    cost-center = var.cost_center
    managed-by  = "terraform"
  }
}

provider "google" {
  # Defaults for every resource that doesn't set its own.
  project = var.project_id
  region  = var.region
  zone    = "${var.region}-a"

  default_labels = local.labels
}
