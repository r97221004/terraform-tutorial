output "namespace" {
  description = "Namespace the model server runs in."
  value       = kubernetes_namespace_v1.serving.metadata[0].name
}

output "port_forward_api" {
  description = "Reach the vLLM API on localhost:8000."
  value       = "kubectl -n ${local.namespace} port-forward svc/${kubernetes_service_v1.vllm.metadata[0].name} 8000:8000"
}

output "port_forward_ui" {
  description = "Reach the chat UI on localhost:8080 (if enable_ui)."
  value       = var.enable_ui ? "kubectl -n ${local.namespace} port-forward svc/open-webui 8080:80" : null
}
