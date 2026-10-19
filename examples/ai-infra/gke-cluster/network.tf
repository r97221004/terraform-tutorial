# The network from the Networking chapter, through the module from Writing Modules.
module "network" {
  source = "../../modules/writing-modules/modules/vpc"

  project_id = google_project_service.enabled["compute.googleapis.com"].project
  name       = "ml-vpc"
  region     = var.region

  ip_ranges = {
    nodes    = "10.10.0.0/20"
    pods     = "10.16.0.0/14"
    services = "10.10.16.0/20"
  }
}
