locals {
  # Conditional: production keeps old object versions, other environments don't.
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

resource "google_storage_bucket" "serving" {
  name     = "${var.project_id}-expressions-${var.environment}"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = !local.is_prod

  versioning {
    enabled = local.is_prod
  }

  # dynamic block: one lifecycle_rule per entry in var.storage_tiers.
  dynamic "lifecycle_rule" {
    for_each = var.storage_tiers
    content {
      condition {
        age = lifecycle_rule.value
      }
      action {
        type          = "SetStorageClass"
        storage_class = lifecycle_rule.key
      }
    }
  }

  # Optional nested block: zero or one cors block, depending on the input.
  dynamic "cors" {
    for_each = length(var.cors_origins) > 0 ? [var.cors_origins] : []
    content {
      origin          = cors.value
      method          = ["GET", "HEAD"]
      response_header = ["Content-Type"]
      max_age_seconds = 3600
    }
  }
}

# templatefile renders a file from a template, with loops and conditionals.
resource "google_storage_bucket_object" "serving_config" {
  bucket       = google_storage_bucket.serving.name
  name         = "config/serving.yaml"
  content_type = "application/yaml"

  content = templatefile("${path.module}/templates/serving.yaml.tftpl", {
    environment = var.environment
    models      = local.enabled_models
    is_prod     = local.is_prod
  })
}

# The same kind of document, built with yamlencode instead of a template.
resource "google_storage_bucket_object" "model_index" {
  bucket       = google_storage_bucket.serving.name
  name         = "config/models.yaml"
  content_type = "application/yaml"

  content = yamlencode({
    environment = var.environment
    total_gpus  = local.total_gpus
    models      = local.gpus_by_model
  })
}
