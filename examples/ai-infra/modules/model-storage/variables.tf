variable "project_id" {
  description = "Project for the bucket and repositories."
  type        = string
}

variable "region" {
  description = "Same region as the GPUs, so reads stay local and free of egress charges."
  type        = string
}

variable "reader_principal" {
  description = "IAM principal that reads the weights: the model server's Kubernetes service account."
  type        = string
}

variable "node_service_account_member" {
  description = "IAM member of the node service account, which pulls images."
  type        = string
}
