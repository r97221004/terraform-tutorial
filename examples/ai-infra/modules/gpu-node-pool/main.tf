resource "google_container_node_pool" "l4_spot" {
  project  = var.project_id
  name     = var.name
  cluster  = var.cluster_id
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
    machine_type = var.machine_type # g2-standard-4: 4 vCPU, 16 GB RAM, 1 x NVIDIA L4 (24 GB)
    spot         = var.spot         # 60-90% cheaper; can be reclaimed at any time

    guest_accelerator {
      type  = var.gpu_type
      count = 1

      # GKE installs the NVIDIA driver itself.
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    disk_type    = "pd-balanced"
    disk_size_gb = 100 # model-serving images are large

    service_account = var.node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot = true
    }

    labels = {
      pool = var.name
    }

    # GKE adds the nvidia.com/gpu=present:NoSchedule taint to GPU nodes by
    # itself, so only Pods that request a GPU (and tolerate it) land here.
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
