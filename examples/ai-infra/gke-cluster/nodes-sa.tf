# Nodes run as their own service account, never the Compute Engine default SA.
resource "google_service_account" "nodes" {
  project      = google_project_service.enabled["iam.googleapis.com"].project
  account_id   = "gke-nodes"
  display_name = "GKE nodes"
}

# The minimum a node needs: write logs and metrics, read images.
resource "google_project_iam_member" "nodes" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = google_service_account.nodes.member
}
