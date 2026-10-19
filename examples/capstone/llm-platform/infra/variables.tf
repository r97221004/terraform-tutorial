variable "project_id" {
  description = "The GCP project. Set via TF_VAR_project_id."
  type        = string
}

variable "region" {
  description = "Region for the network, bucket, registry, and GPUs. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zone of the (zonal) cluster."
  type        = string
  default     = "us-central1-a"
}

variable "gpu_zones" {
  description = "Zones the GPU pool may use."
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "max_gpu_nodes" {
  description = "Upper limit for the GPU pool. Must fit your GPU quota."
  type        = number
  default     = 1
}
