output "port_forward_api" {
  description = "Reach the vLLM API on localhost:8000."
  value       = module.vllm.port_forward_api
}

output "port_forward_ui" {
  description = "Reach the chat UI on localhost:8080 (if enable_ui)."
  value       = module.vllm.port_forward_ui
}
