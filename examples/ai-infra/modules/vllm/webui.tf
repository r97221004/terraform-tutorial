# A chat UI in front of vLLM, from a public Helm chart.
resource "helm_release" "open_webui" {
  count = var.enable_ui ? 1 : 0

  name       = "open-webui"
  namespace  = kubernetes_namespace_v1.serving.metadata[0].name
  repository = "https://helm.openwebui.com"
  chart      = "open-webui"
  version    = "16.6.0" # pin charts exactly, like modules

  values = [yamlencode({
    ollama    = { enabled = false } # we bring our own model server
    pipelines = { enabled = false }
    websocket = { enabled = false }

    # vLLM speaks the OpenAI API; point the UI at its Service.
    openaiBaseApiUrl = "http://${kubernetes_service_v1.vllm.metadata[0].name}.${local.namespace}.svc.cluster.local:8000/v1"
  })]
}
