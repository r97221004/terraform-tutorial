locals {
  # Conditional: production configs get more replicas and read-only files.
  is_prod = var.environment == "prod"

  # String functions turn free text into a valid label value
  # ("ML Platform Team" -> "ml-platform-team").
  owner_label = substr(replace(lower(trimspace(var.owner)), "/[^a-z0-9_-]+/", "-"), 0, 63)

  labels = {
    environment = var.environment
    owner       = local.owner_label
    managed-by  = "terraform"
  }

  # for expression with a filter: keep only the enabled models.
  enabled_models = [for m in var.models : m if m.enabled]

  # for expression producing a map: model name => GPUs it needs.
  gpus_by_model = { for m in local.enabled_models : m.name => m.gpus }

  # Splat: every enabled model's name.
  model_names = local.enabled_models[*].name

  total_gpus = sum(values(local.gpus_by_model))

  # Network function: carve one /20 per environment out of a /16.
  subnet_cidrs = {
    for i, env in ["dev", "staging", "prod"] : env => cidrsubnet("10.10.0.0/16", 4, i)
  }
}

# templatefile renders a file from a template, with loops and conditionals.
resource "local_file" "serving_config" {
  filename             = "${path.module}/out/${var.environment}/serving.yaml"
  file_permission      = local.is_prod ? "0444" : "0644"
  directory_permission = "0755"

  content = templatefile("${path.module}/templates/serving.yaml.tftpl", {
    environment = var.environment
    models      = local.enabled_models
    is_prod     = local.is_prod
  })
}

# The same kind of document, built with yamlencode instead of a template.
resource "local_file" "model_index" {
  filename             = "${path.module}/out/${var.environment}/models.yaml"
  file_permission      = local.is_prod ? "0444" : "0644"
  directory_permission = "0755"

  content = yamlencode({
    environment = var.environment
    labels      = local.labels
    total_gpus  = local.total_gpus
    models      = local.gpus_by_model
  })
}

# A zip bundle with one file per enabled model. `source` is a nested block,
# so the per-model files come from dynamic blocks, not a for expression.
resource "archive_file" "bundle" {
  type        = "zip"
  output_path = "${path.module}/out/${var.environment}/bundle.zip"

  # dynamic block: one source block per enabled model.
  dynamic "source" {
    for_each = local.gpus_by_model
    content {
      filename = "models/${source.key}.yaml"
      content  = yamlencode({ name = source.key, gpus = source.value })
    }
  }

  # Optional nested block: zero or one NOTES.txt, depending on the input.
  dynamic "source" {
    for_each = var.release_notes != "" ? [var.release_notes] : []
    content {
      filename = "NOTES.txt"
      content  = source.value
    }
  }
}
