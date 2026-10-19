# vLLM and Open WebUI, from the shared module (also used by the capstone).
# The providers it uses are configured in providers.tf.
module "vllm" {
  source = "../modules/vllm"

  image_repository = "${var.region}-docker.pkg.dev/${var.project_id}/dockerhub"
  models_bucket    = "${var.project_id}-models"
  model            = var.model
  vllm_version     = var.vllm_version
}
