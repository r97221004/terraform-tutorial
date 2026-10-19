# The workloads: the same vllm module as the Kubernetes & Helm chapter.
module "vllm" {
  source = "../../../ai-infra/modules/vllm"

  image_repository = "${var.region}-docker.pkg.dev/${var.project_id}/dockerhub"
  models_bucket    = "${var.project_id}-models"
  model            = var.model
  vllm_version     = var.vllm_version
  enable_ui        = var.enable_ui
}
