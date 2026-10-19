output "models_bucket" {
  description = "Upload model weights here."
  value       = module.storage.models_bucket
}

output "vllm_image" {
  description = "The vLLM image, pulled through the Docker Hub cache."
  value       = "${module.storage.dockerhub_repository}/vllm/vllm-openai:v0.31.0"
}

output "serving_repository" {
  description = "Push your own images here."
  value       = module.storage.serving_repository
}
