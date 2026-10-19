resource "google_container_cluster" "ml" {
  name     = var.cluster_name
  location = var.zone # a zone: a zonal cluster. A region would make it regional.

  network    = module.network.network_id
  subnetwork = module.network.subnet_id

  # Manage node pools as separate resources, so they can change independently.
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  # VPC-native networking with the secondary ranges from the network module.
  ip_allocation_policy {
    cluster_secondary_range_name  = module.network.pods_range_name
    services_secondary_range_name = module.network.services_range_name
  }

  # Nodes get no public IPs; they reach the internet through Cloud NAT.
  private_cluster_config {
    enable_private_nodes = true
  }

  # kubectl talks to the control plane through a DNS endpoint protected by IAM,
  # so there's no IP allowlist to maintain.
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
  }

  # The IP endpoint stays on for the nodes, but only listed networks may use it.
  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled = false

    dynamic "cidr_blocks" {
      for_each = var.authorized_cidrs
      content {
        cidr_block = cidr_blocks.value
      }
    }
  }

  # Pods authenticate to Google APIs as Kubernetes service accounts (Workload Identity chapter).
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  addons_config {
    # Mount GCS buckets into Pods: used for model weights later.
    gcs_fuse_csi_driver_config {
      enabled = true
    }
  }

  # Break down the bill by namespace and label.
  cost_management_config {
    enabled = true
  }

  # The google provider protects clusters by default. Off for this tutorial,
  # so `terraform destroy` works; leave it on (true) for real clusters.
  deletion_protection = false

  depends_on = [google_project_service.enabled]
}

# A small CPU pool for system Pods (DNS, metrics, the GCS FUSE driver).
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
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA" # required for Workload Identity
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
