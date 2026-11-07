# The LLM platform's infrastructure: the same modules as Parts 5-6, in one place.
# The Kubernetes workloads live in ../app, a separate configuration.

locals {
  namespace = "ml-serving"
  ksa_name  = "vllm"
}

resource "google_project_service" "enabled" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
  ])

  service            = each.value
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

# --- Cluster and node pools (GKE Cluster, GPU Node Pools) -------------------

module "gke" {
  source = "../../../ai-infra/modules/gke-cluster"

  project_id = var.project_id
  zone       = var.zone

  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  deletion_protection = false # so the capstone can be torn down; keep true for real clusters

  depends_on = [google_project_service.enabled]
}

module "gpu_pool" {
  source = "../../../ai-infra/modules/gpu-node-pool"

  project_id           = var.project_id
  cluster_id           = module.gke.cluster_id # same configuration: refer to the cluster directly
  zone                 = var.zone
  node_service_account = module.gke.node_service_account

  gpu_zones     = var.gpu_zones
  max_gpu_nodes = var.max_gpu_nodes
}

# --- Model weights and images (Model Storage, Workload Identity) ------------

module "storage" {
  source = "../../../ai-infra/modules/model-storage"

  project_id                  = var.project_id
  region                      = var.region
  reader_principal            = "principal://iam.googleapis.com/projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/${local.namespace}/sa/${local.ksa_name}"
  node_service_account_member = module.gke.node_service_account_member

  depends_on = [google_project_service.enabled]
}
