# --- Cluster and node pools (GKE Cluster, GPU Node Pools) -------------------

resource "google_service_account" "nodes" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "gke-nodes"
  display_name = "GKE nodes"
}

resource "google_project_iam_member" "nodes" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = google_service_account.nodes.member
}

resource "google_container_cluster" "ml" {
  name     = local.cluster_name
  location = var.zone

  network    = module.network.network_id
  subnetwork = module.network.subnet_id

  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = module.network.pods_range_name
    services_secondary_range_name = module.network.services_range_name
  }

  private_cluster_config {
    enable_private_nodes = true
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = false
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  cost_management_config {
    enabled = true
  }

  deletion_protection = false # so the capstone can be torn down; keep true for real clusters

  depends_on = [google_project_service.enabled]
}

locals {
  node_config_common = {
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

resource "google_container_node_pool" "system" {
  name     = "system"
  cluster  = google_container_cluster.ml.id
  location = var.zone

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type    = "e2-standard-4"
    disk_size_gb    = 50
    service_account = local.node_config_common.service_account
    oauth_scopes    = local.node_config_common.oauth_scopes

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot = true
    }

    labels = {
      pool = "system"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

resource "google_container_node_pool" "l4_spot" {
  name     = "l4-spot"
  cluster  = google_container_cluster.ml.id
  location = var.zone

  node_locations     = var.gpu_zones
  initial_node_count = 0

  autoscaling {
    total_min_node_count = 0
    total_max_node_count = var.max_gpu_nodes
    location_policy      = "ANY"
  }

  node_config {
    machine_type = "g2-standard-4"
    spot         = true

    guest_accelerator {
      type  = "nvidia-l4"
      count = 1

      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    disk_type       = "pd-balanced"
    disk_size_gb    = 100
    service_account = local.node_config_common.service_account
    oauth_scopes    = local.node_config_common.oauth_scopes

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot = true
    }

    labels = {
      pool = "l4-spot"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
