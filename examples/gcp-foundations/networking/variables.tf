variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Region for the subnet, router, and NAT. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Name of the VPC. Subnet, router, and firewall names are derived from it."
  type        = string
  default     = "ml-vpc"
}

variable "nodes_and_services_cidr" {
  description = "A /16 split into the node range and the Kubernetes Service range."
  type        = string
  default     = "10.10.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.nodes_and_services_cidr)) && endswith(var.nodes_and_services_cidr, "/16")
    error_message = "nodes_and_services_cidr must be an IPv4 /16, such as 10.10.0.0/16."
  }
}

variable "pods_cidr" {
  description = "Range for GKE Pod IPs. Each node takes a /24 from it, so it must be large."
  type        = string
  default     = "10.16.0.0/14"

  validation {
    condition     = can(cidrnetmask(var.pods_cidr))
    error_message = "pods_cidr must be an IPv4 CIDR block, such as 10.16.0.0/14."
  }
}
