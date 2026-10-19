output "port_forward_api" {
  description = "Reach the vLLM API on localhost:8000."
  value       = "kubectl -n ${local.namespace} port-forward svc/vllm 8000:8000"
}

output "port_forward_ui" {
  description = "Reach the chat UI on localhost:8080."
  value       = "kubectl -n ${local.namespace} port-forward svc/open-webui 8080:80"
}
