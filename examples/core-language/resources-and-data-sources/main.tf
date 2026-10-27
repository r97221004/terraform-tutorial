# Resources are things Terraform MANAGES: it creates, updates, and deletes them.

locals {
  # jsondecode turns the file's text into a value you can index.
  team = jsondecode(data.local_file.team.content)
}

resource "random_pet" "dataset" {
  # Every argument is optional: length defaults to 2, separator to "-".
  prefix = local.team.team
}

resource "local_file" "manifest" {
  # Required argument.
  filename = "${path.module}/out/manifest.json"

  # Exactly one content source is required: content, content_base64, or source.
  content = jsonencode({
    dataset     = random_pet.dataset.id
    owner       = local.team.owner
    cost_center = local.team.cost_center
  })

  # Optional arguments. Leave one out and the provider picks a default.
  file_permission      = "0644"
  directory_permission = "0755"
}
