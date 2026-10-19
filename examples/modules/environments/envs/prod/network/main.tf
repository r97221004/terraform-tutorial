# prod: everything that makes prod different from dev is in this file.
locals {
  environment = "prod"
  region      = "us-central1"
}

provider "google" {
  project = var.project_id
  region  = local.region

  default_labels = {
    environment = local.environment
    managed-by  = "terraform"
  }
}

resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

module "network" {
  source = "../../../../writing-modules/modules/vpc"

  project_id = google_project_service.compute.project
  name       = "ml-vpc-${local.environment}"
  region     = local.region

  # Different ranges from dev, so the two networks could be peered later.
  ip_ranges = {
    nodes    = "10.40.0.0/20"
    pods     = "10.48.0.0/14"
    services = "10.40.16.0/20"
  }

  enable_nat          = true
  iap_ssh_target_tags = [] # no SSH into prod nodes, even through IAP
}

output "network" {
  description = "What the prod GKE configuration needs."
  value = {
    network        = module.network.network_name
    subnet         = module.network.subnet_name
    pods_range     = module.network.pods_range_name
    services_range = module.network.services_range_name
  }
}
