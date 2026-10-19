variable "project_id" {
  description = "Project of the cluster."
  type        = string
}

variable "cluster_id" {
  description = "ID of the cluster to add the pool to (projects/P/locations/L/clusters/N)."
  type        = string
}

variable "zone" {
  description = "Location of the (zonal) cluster."
  type        = string
}

variable "node_service_account" {
  description = "Email of the service account the nodes run as."
  type        = string
}

variable "name" {
  description = "Node pool name."
  type        = string
  default     = "l4-spot"
}

variable "gpu_zones" {
  description = "Zones the GPU pool may create nodes in. More zones = better odds of finding Spot GPUs."
  type        = list(string)
}

variable "max_gpu_nodes" {
  description = "Upper limit for the whole pool. Must fit within your GPU quota."
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "Machine type; must match the GPU (g2-standard-* for L4)."
  type        = string
  default     = "g2-standard-4"
}

variable "gpu_type" {
  description = "GPU type, e.g. nvidia-l4 or nvidia-tesla-t4."
  type        = string
  default     = "nvidia-l4"
}

variable "spot" {
  description = "Use Spot VMs: much cheaper, can be reclaimed at any time."
  type        = bool
  default     = true
}
