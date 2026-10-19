resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = var.name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "gke" {
  project       = var.project_id
  name          = "${var.name}-gke-${var.region}"
  network       = google_compute_network.vpc.id
  region        = var.region
  ip_cidr_range = var.ip_ranges.nodes

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.ip_ranges.pods
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.ip_ranges.services
  }

  private_ip_google_access = true
}

resource "google_compute_router" "nat" {
  count = var.enable_nat ? 1 : 0

  project = var.project_id
  name    = "${var.name}-router-${var.region}"
  network = google_compute_network.vpc.id
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  count = var.enable_nat ? 1 : 0

  project = var.project_id
  name    = "${var.name}-nat-${var.region}"
  router  = google_compute_router.nat[0].name
  region  = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "allow_internal" {
  project   = var.project_id
  name      = "${var.name}-allow-internal"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"

  source_ranges = [var.ip_ranges.nodes, var.ip_ranges.pods]

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
  count = length(var.iap_ssh_target_tags) > 0 ? 1 : 0

  project   = var.project_id
  name      = "${var.name}-allow-iap-ssh"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags   = var.iap_ssh_target_tags

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
