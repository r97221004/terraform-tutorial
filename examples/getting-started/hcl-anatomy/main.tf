locals {
  name_prefix = "${var.team}-${var.environment}"

  labels = {
    team        = var.team
    environment = var.environment
  }
}

resource "random_pet" "server" {
  length = 2

  # An ARGUMENT whose value is a map: note the `=`.
  # A different team or environment gets a new name.
  keepers = local.labels

  # A nested BLOCK: no `=`. (lifecycle is covered in Meta-Arguments.)
  lifecycle {
    create_before_destroy = true
  }
}

resource "local_file" "readme" {
  filename             = "${path.module}/out/${local.name_prefix}.txt"
  file_permission      = "0644"
  directory_permission = "0755"

  # Referencing another resource's attribute creates an implicit dependency:
  # Terraform creates the name first, and destroys this file first.
  content = <<-EOT
    This file is managed by Terraform.
    Server:      ${random_pet.server.id}
    Environment: ${upper(var.environment)}
  EOT
}
