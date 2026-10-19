# dev: everything that makes dev different from prod is in this file.
locals {
  environment = "dev"
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

  ip_ranges = {
    nodes    = "10.10.0.0/20"
    pods     = "10.16.0.0/14"
    services = "10.10.16.0/20"
  }

  enable_nat = true
}

output "network" {
  description = "What the dev GKE configuration needs."
  value = {
    network        = module.network.network_name
    subnet         = module.network.subnet_name
    pods_range     = module.network.pods_range_name
    services_range = module.network.services_range_name
  }
}
