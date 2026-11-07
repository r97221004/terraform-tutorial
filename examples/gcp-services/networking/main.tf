resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

locals {
  # IP plan. Ranges in one VPC (and in any network you peer with) must not overlap.
  nodes_cidr    = cidrsubnet(var.nodes_and_services_cidr, 4, 0) # 10.10.0.0/20:  4,096 node IPs
  services_cidr = cidrsubnet(var.nodes_and_services_cidr, 4, 1) # 10.10.16.0/20: 4,096 Service IPs
}

# ---------------------------------------------------------------------------
# The VPC: custom mode, so it has only the subnets we create.
# ---------------------------------------------------------------------------

resource "google_compute_network" "vpc" {
  project                 = google_project_service.compute.project
  name                    = var.network_name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "gke" {
  name          = "${var.network_name}-gke-${var.region}"
  network       = google_compute_network.vpc.id
  region        = var.region
  ip_cidr_range = local.nodes_cidr

  # GKE (VPC-native) takes Pod and Service IPs from these named ranges.
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = local.services_cidr
  }

  # Lets VMs without public IPs reach Google APIs (GCS, Artifact Registry, ...).
  private_ip_google_access = true
}

# ---------------------------------------------------------------------------
# Cloud NAT: outbound internet for VMs without public IPs (pulling model
# weights from Hugging Face, pip installs). Nothing can connect IN through it.
# ---------------------------------------------------------------------------

resource "google_compute_router" "nat" {
  name    = "${var.network_name}-router-${var.region}"
  network = google_compute_network.vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name   = "${var.network_name}-nat-${var.region}"
  router = google_compute_router.nat.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"] # nodes and Pods
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ---------------------------------------------------------------------------
# Firewall rules. A VPC denies all ingress by default; these open only
# what's needed. GKE adds its own rules for the cluster it creates.
# ---------------------------------------------------------------------------

resource "google_compute_firewall" "allow_internal" {
  name      = "${var.network_name}-allow-internal"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  source_ranges = [local.nodes_cidr, var.pods_cidr]

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name      = "${var.network_name}-allow-iap-ssh"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 1000

  # Identity-Aware Proxy's range: SSH only through `gcloud compute ssh --tunnel-through-iap`,
  # never from the internet.
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["allow-iap-ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
