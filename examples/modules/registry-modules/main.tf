resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# The same network as the Networking chapter, built with Google's own modules.
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 18.3" # >= 18.3.0, < 19.0.0: fixes and features, no breaking changes

  project_id   = google_project_service.compute.project
  network_name = "ml-vpc"
  routing_mode = "REGIONAL" # the module's default is GLOBAL

  subnets = [
    {
      subnet_name           = "ml-vpc-gke-${var.region}"
      subnet_ip             = "10.10.0.0/20"
      subnet_region         = var.region
      subnet_private_access = "true" # a string, not a bool, in this module
    },
  ]

  secondary_ranges = {
    "ml-vpc-gke-${var.region}" = [
      { range_name = "pods", ip_cidr_range = "10.16.0.0/14" },
      { range_name = "services", ip_cidr_range = "10.10.16.0/20" },
    ]
  }

  ingress_rules = [
    {
      name          = "ml-vpc-allow-internal"
      source_ranges = ["10.10.0.0/20", "10.16.0.0/14"]
      allow         = [{ protocol = "tcp" }, { protocol = "udp" }, { protocol = "icmp" }]
    },
    {
      name          = "ml-vpc-allow-iap-ssh"
      source_ranges = ["35.235.240.0/20"]
      target_tags   = ["allow-iap-ssh"]
      allow         = [{ protocol = "tcp", ports = ["22"] }]
    },
  ]
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 9.1"

  project_id = var.project_id
  name       = "ml-vpc-router-${var.region}"
  network    = module.vpc.network_name
  region     = var.region

  nats = [{
    name                               = "ml-vpc-nat-${var.region}"
    source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  }]
}
