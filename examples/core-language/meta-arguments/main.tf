locals {
  # GCS charges early-deletion fees if objects are deleted before these ages.
  min_days = {
    STANDARD = 0
    NEARLINE = 30
    COLDLINE = 90
    ARCHIVE  = 365
  }
}

# for_each over a map: one manifest per entry, addressed by key,
# e.g. local_file.dataset["raw"]. A storage job reads these to set up buckets.
resource "local_file" "dataset" {
  for_each = var.datasets

  filename             = "${path.module}/out/datasets/${each.key}.json"
  file_permission      = "0644"
  directory_permission = "0755"

  content = jsonencode({
    stage          = each.key
    storage_class  = each.value.storage_class
    retention_days = each.value.retention_days
  })

  lifecycle {
    # Checked during plan, before anything is created or changed.
    precondition {
      condition     = coalesce(each.value.retention_days, 36500) >= local.min_days[each.value.storage_class]
      error_message = "Dataset \"${each.key}\": retention_days is shorter than the minimum storage duration of ${each.value.storage_class}, so every deletion would pay an early-deletion fee."
    }
  }
}

# count as an on/off switch: zero or one file.
resource "local_file" "scratch" {
  count = var.enable_scratch ? 1 : 0

  filename             = "${path.module}/out/scratch/README.txt"
  content              = "Scratch space. Anything here may be deleted.\n"
  file_permission      = "0644"
  directory_permission = "0755"
}

# for_each over a set of strings: each.key and each.value are the same string.
resource "local_file" "model_card" {
  for_each = var.models

  filename             = "${path.module}/out/model-cards/${each.key}.md"
  content              = "# ${each.key}\n\nEvaluation results go here.\n"
  file_permission      = "0644"
  directory_permission = "0755"
}

# A marker that downstream jobs wait for. Nothing in it refers to the model
# cards, so depends_on is the only way to say "write this one last".
resource "local_file" "ready" {
  filename             = "${path.module}/out/model-cards/_READY"
  content              = "ok\n"
  file_permission      = "0644"
  directory_permission = "0755"

  depends_on = [local_file.model_card]
}
