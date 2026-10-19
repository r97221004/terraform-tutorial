variable "project_id" {
  description = "Project to create the cluster in."
  type        = string
}

variable "zone" {
  description = "Zone for the (zonal) cluster's control plane and system nodes."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
  default     = "ml-gke"
}

variable "network_id" {
  description = "VPC ID, from the vpc module."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID, from the vpc module."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for Pods."
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for Services."
  type        = string
}

variable "authorized_cidrs" {
  description = "Extra CIDR blocks allowed to reach the control plane's IP endpoint. kubectl normally uses the DNS endpoint instead."
  type        = list(string)
  default     = []
}

variable "system_machine_type" {
  description = "Machine type of the system node pool."
  type        = string
  default     = "e2-standard-4"
}

variable "deletion_protection" {
  description = "Protect the cluster from terraform destroy. false only for labs."
  type        = bool
  default     = true
}
