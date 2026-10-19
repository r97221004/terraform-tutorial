# Unit tests for the vpc module: plan only, mocked provider, no credentials.
#   cd examples/modules/writing-modules/modules/vpc && terraform init && terraform test

mock_provider "google" {}

variables {
  project_id = "test-project"
  name       = "ml-vpc"
  region     = "us-central1"
  ip_ranges = {
    nodes    = "10.10.0.0/20"
    pods     = "10.16.0.0/14"
    services = "10.10.16.0/20"
  }
}

run "defaults_build_a_private_gke_network" {
  command = plan

  assert {
    condition     = google_compute_network.vpc.auto_create_subnetworks == false
    error_message = "The VPC must be custom mode."
  }

  assert {
    condition     = google_compute_subnetwork.gke.name == "ml-vpc-gke-us-central1"
    error_message = "Subnet name should be <name>-gke-<region>."
  }

  assert {
    condition     = google_compute_subnetwork.gke.private_ip_google_access == true
    error_message = "Private Google Access must be on for private nodes."
  }

  assert {
    condition = (
      google_compute_subnetwork.gke.secondary_ip_range[0].range_name == "pods" &&
      google_compute_subnetwork.gke.secondary_ip_range[1].range_name == "services"
    )
    error_message = "GKE expects secondary ranges named pods and services."
  }

  assert {
    condition     = length(google_compute_router_nat.nat) == 1 && length(google_compute_firewall.allow_iap_ssh) == 1
    error_message = "NAT and the IAP SSH rule are on by default."
  }

  assert {
    condition     = output.pods_range_name == "pods" && output.services_range_name == "services"
    error_message = "Range name outputs must match the subnet."
  }
}

run "features_can_be_switched_off" {
  command = plan

  variables {
    enable_nat          = false
    iap_ssh_target_tags = []
  }

  assert {
    condition     = length(google_compute_router.nat) == 0 && length(google_compute_router_nat.nat) == 0
    error_message = "enable_nat = false must drop the router and NAT."
  }

  assert {
    condition     = length(google_compute_firewall.allow_iap_ssh) == 0
    error_message = "An empty iap_ssh_target_tags must drop the SSH rule."
  }
}

run "internal_rule_covers_nodes_and_pods" {
  command = plan

  assert {
    condition     = toset(google_compute_firewall.allow_internal.source_ranges) == toset(["10.10.0.0/20", "10.16.0.0/14"])
    error_message = "allow_internal must allow exactly the node and Pod ranges."
  }
}

run "rejects_invalid_name" {
  command = plan

  variables {
    name = "ML_VPC"
  }

  expect_failures = [var.name]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    ip_ranges = {
      nodes    = "10.10.0.0/20"
      pods     = "not-a-cidr"
      services = "10.10.16.0/20"
    }
  }

  expect_failures = [var.ip_ranges]
}
