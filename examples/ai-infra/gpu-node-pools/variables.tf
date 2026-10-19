variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Region of the cluster. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone of the (zonal) cluster from the GKE Cluster chapter."
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "Name of the existing cluster to add the GPU pool to."
  type        = string
  default     = "ml-gke"
}

variable "gpu_zones" {
  description = "Zones the GPU pool may create nodes in. More zones = better odds of finding Spot GPUs."
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "max_gpu_nodes" {
  description = "Upper limit for the whole pool. Must fit within your GPU quota."
  type        = number
  default     = 1
}
