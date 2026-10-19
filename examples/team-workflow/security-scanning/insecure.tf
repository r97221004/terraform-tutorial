# ⚠️ DELIBERATELY INSECURE. Scan this file; never apply it.
# Each resource contains a mistake that shows up in real code.

# A bucket anyone on the internet can read, without uniform access.
resource "google_storage_bucket" "shared_weights" {
  name     = "${var.project_id}-shared-weights"
  location = var.region
}

resource "google_storage_bucket_iam_member" "public" {
  bucket = google_storage_bucket.shared_weights.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# SSH open to the whole internet.
resource "google_compute_firewall" "ssh_anywhere" {
  name          = "allow-ssh-anywhere"
  network       = "default"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# A basic role on the whole project, granted to a person.
resource "google_project_iam_member" "dev_owner" {
  project = var.project_id
  role    = "roles/owner"
  member  = "user:dev@example.com"
}

# A GKE cluster with public nodes and no Workload Identity.
resource "google_container_cluster" "quick" {
  name                     = "quick-gke"
  location                 = "us-central1-a"
  initial_node_count       = 1
  remove_default_node_pool = true
  deletion_protection      = false
}
