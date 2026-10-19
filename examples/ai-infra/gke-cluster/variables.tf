variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Region for the network. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone for the (zonal) cluster's control plane and system nodes."
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "GKE cluster name. Later chapters look the cluster up by this name."
  type        = string
  default     = "ml-gke"
}

variable "authorized_cidrs" {
  description = "Extra CIDR blocks allowed to reach the control plane's IP endpoint. kubectl normally uses the DNS endpoint instead."
  type        = list(string)
  default     = []
}
