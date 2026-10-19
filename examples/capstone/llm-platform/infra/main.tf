# The LLM platform's infrastructure: everything from Parts 3-5 in one place.
# The Kubernetes workloads live in ../app, a separate configuration.

locals {
  cluster_name = "ml-gke"
  namespace    = "ml-serving"
  ksa_name     = "vllm"
}

resource "google_project_service" "enabled" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

# Read at plan time. No depends_on: that would defer the read to apply
# (the <= from Resources & Data Sources). Setup enabled the API it needs.
data "google_project" "this" {}

# --- Network (Networking, Writing Modules) ----------------------------------

module "network" {
  source = "../../../modules/writing-modules/modules/vpc"

  project_id = google_project_service.enabled["compute.googleapis.com"].project
  name       = "ml-vpc"
  region     = var.region

  ip_ranges = {
    nodes    = "10.10.0.0/20"
    pods     = "10.16.0.0/14"
    services = "10.10.16.0/20"
  }
}
