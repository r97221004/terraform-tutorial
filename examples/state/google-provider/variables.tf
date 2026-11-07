# No default: each person uses their own project, so Terraform asks for the
# value when you run plan or apply unless you pass it in. Any of these works:
#   export TF_VAR_project_id="$(gcloud config get-value project)"
#   terraform plan -var="project_id=my-project-id"
#   echo 'project_id = "my-project-id"' > terraform.tfvars
variable "project_id" {
  description = "The GCP project to create resources in. Set via TF_VAR_project_id."
  type        = string
}

# Has a default, so Terraform never asks for it. Override the same ways as above.
variable "region" {
  description = "Default region. Set via TF_VAR_region."
  type        = string
  default     = "us-central1"
}
