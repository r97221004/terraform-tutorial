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

resource "google_container_node_pool" "l4_spot" {
  name     = "l4-spot"
  cluster  = data.google_container_cluster.ml.id
  location = var.zone

  # Nodes may be created in any of these zones (all in the cluster's region).
  node_locations = var.gpu_zones

  # Start with no nodes; the cluster autoscaler adds them when a Pod asks for a GPU.
  initial_node_count = 0

  autoscaling {
    total_min_node_count = 0 # scale to zero when no GPU Pods are running
    total_max_node_count = var.max_gpu_nodes
    location_policy      = "ANY" # take capacity in whichever zone has it (best for Spot)
  }

  node_config {
    machine_type = "g2-standard-4" # 4 vCPU, 16 GB RAM, 1 x NVIDIA L4 (24 GB)
    spot         = true            # 60-90% cheaper; can be reclaimed at any time

    guest_accelerator {
      type  = "nvidia-l4"
      count = 1

      # GKE installs the NVIDIA driver itself.
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    disk_type    = "pd-balanced"
    disk_size_gb = 100 # model-serving images are large

    service_account = local.node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot = true
    }

    labels = {
      pool = "l4-spot"
    }

    # GKE adds the nvidia.com/gpu=present:NoSchedule taint to GPU nodes by
    # itself, so only Pods that request a GPU (and tolerate it) land here.
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
