# One web server VM on the project's default network: an external IP so it
# can install packages and serve HTTP, and SSH only through IAP.

resource "google_project_service" "enabled" {
  for_each = toset(["compute.googleapis.com", "iam.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

# The VM's own identity. It has no roles: nothing on this VM calls Google APIs.
resource "google_service_account" "web" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "web-server"
  display_name = "Compute Engine chapter web server"
}

# A second disk for data. It's its own resource, so it outlives the VM:
# when the VM is replaced, the new one attaches this same disk.
resource "google_compute_disk" "data" {
  project = google_project_service.enabled["compute.googleapis.com"].project
  name    = "web-1-data"
  zone    = var.zone
  size    = 10
  type    = "pd-standard" # with the boot disk, 20 GB of the free tier's 30
}

resource "google_compute_instance" "web" {
  project      = google_project_service.enabled["compute.googleapis.com"].project
  name         = "web-1"
  zone         = var.zone
  machine_type = "e2-micro" # the free tier's machine type

  # Lets Terraform stop the VM to change settings such as machine_type.
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" # an image family: its newest image
      size  = 10
      type  = "pd-standard" # the free tier covers 30 GB of standard disk
    }
  }

  # On the VM: /dev/disk/by-id/google-data. startup.sh formats and mounts it.
  attached_disk {
    source      = google_compute_disk.data.id
    device_name = "data"
  }

  network_interface {
    network = "default"

    # An ephemeral external IP. The default network has no Cloud NAT, so
    # without one the VM couldn't reach the internet to install nginx.
    access_config {}
  }

  service_account {
    email  = google_service_account.web.email
    scopes = ["cloud-platform"] # IAM roles decide what the VM can do, not scopes
  }

  # Runs as root on every boot. Changing it replaces the VM.
  metadata_startup_script = file("${path.module}/startup.sh")

  # The firewall rules below pick this VM by these tags.
  tags = ["http-server", "allow-iap-ssh"]

  labels = {
    component = "web"
  }
}

resource "google_compute_firewall" "allow_http" {
  project   = google_project_service.enabled["compute.googleapis.com"].project
  name      = "web-allow-http"
  network   = "default"
  direction = "INGRESS"

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  project   = google_project_service.enabled["compute.googleapis.com"].project
  name      = "web-allow-iap-ssh"
  network   = "default"
  direction = "INGRESS"

  # Identity-Aware Proxy's range: SSH only through
  # `gcloud compute ssh --tunnel-through-iap`, never from the internet.
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["allow-iap-ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
