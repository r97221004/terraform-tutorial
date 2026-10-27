locals {
  # Name things once, use the names everywhere.
  name_prefix = "${var.team}-${var.environment}"
  config_name = "${local.name_prefix}-${var.serving.name_suffix}"

  # Labels for everything this configuration creates.
  # Keys in extra_labels can't override these, because these come last.
  labels = merge(var.extra_labels, {
    environment = var.environment
    team        = var.team
    managed-by  = "terraform"
  })
}

resource "local_file" "serving" {
  filename             = "${path.module}/out/${local.config_name}.json"
  file_permission      = "0644"
  directory_permission = "0755"

  content = jsonencode({
    name       = local.config_name
    gpu_type   = var.serving.gpu_type
    replicas   = var.serving.replicas
    max_tokens = var.serving.max_tokens
    labels     = local.labels
  })
}
