# The cluster is owned by the GKE Cluster chapter's configuration. This
# configuration only adds a node pool to it, so it looks the cluster up.
data "google_container_cluster" "ml" {
  name     = var.cluster_name
  location = var.zone
}

locals {
  # Created in the GKE Cluster chapter; referred to by its well-known name.
  node_service_account = "gke-nodes@${var.project_id}.iam.gserviceaccount.com"
}

module "gpu_pool" {
  source = "../modules/gpu-node-pool"

  project_id           = var.project_id
  cluster_id           = data.google_container_cluster.ml.id
  zone                 = var.zone
  node_service_account = local.node_service_account

  gpu_zones     = var.gpu_zones
  max_gpu_nodes = var.max_gpu_nodes
}
