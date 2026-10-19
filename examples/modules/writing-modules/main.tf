resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

locals {
  base_cidr = "10.10.0.0/16"
}

# The same network as the Networking chapter, now in eight lines.
module "network" {
  source = "./modules/vpc"

  # Passing the project through the API's resource makes everything in the
  # module wait until the Compute API is enabled.
  project_id = google_project_service.compute.project
  name       = "ml-vpc"
  region     = var.region

  ip_ranges = {
    nodes    = cidrsubnet(local.base_cidr, 4, 0) # 10.10.0.0/20
    pods     = "10.16.0.0/14"
    services = cidrsubnet(local.base_cidr, 4, 1) # 10.10.16.0/20
  }
}
