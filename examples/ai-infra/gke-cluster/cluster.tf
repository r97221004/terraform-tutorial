# The cluster, its system node pool, and the node service account,
# from the shared module (also used by the capstone).
module "gke" {
  source = "../modules/gke-cluster"

  project_id   = var.project_id
  zone         = var.zone
  cluster_name = var.cluster_name

  network_id          = module.network.network_id
  subnet_id           = module.network.subnet_id
  pods_range_name     = module.network.pods_range_name
  services_range_name = module.network.services_range_name

  authorized_cidrs = var.authorized_cidrs

  # So that `terraform destroy` works in this tutorial. Leave it true for real clusters.
  deletion_protection = false

  # Everything in the module waits for the APIs.
  depends_on = [google_project_service.enabled]
}
