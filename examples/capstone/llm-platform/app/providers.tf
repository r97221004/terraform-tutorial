provider "google" {
  project = var.project_id
  region  = var.region
}

# The cluster exists already (GKE Cluster chapter). Read how to reach it.
data "google_container_cluster" "ml" {
  name     = var.cluster_name
  location = var.zone
}

# A short-lived access token for your own Google identity (ADC). Ephemeral:
# it's fetched on every run and never written to state or a plan file.
ephemeral "google_client_config" "current" {}

locals {
  # The DNS endpoint uses a publicly trusted certificate, so no CA bundle is needed.
  cluster_host = "https://${data.google_container_cluster.ml.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint}"
}

provider "kubernetes" {
  host  = local.cluster_host
  token = ephemeral.google_client_config.current.access_token
}

provider "helm" {
  kubernetes = {
    host  = local.cluster_host
    token = ephemeral.google_client_config.current.access_token
  }
}
