terraform {
  required_version = ">= 1.10"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}

variable "owner" {
  description = "Written into the config file."
  type        = string
  default     = "platform-team"
}

# A random two-word name, like "relaxed-gecko". Generated once, then kept in state.
resource "random_pet" "server" {
  length = 2
}

# A file on your disk, standing in for a cloud resource.
resource "local_file" "config" {
  filename             = "${path.module}/out/server.conf"
  content              = "name=${random_pet.server.id}\nowner=${var.owner}\n"
  file_permission      = "0644"
  directory_permission = "0755"
}

# Built into Terraform: it stores a value in state and creates nothing else.
resource "terraform_data" "release" {
  input = {
    version = "1.0"
  }
}

output "server_name" {
  description = "The generated server name."
  value       = random_pet.server.id
}

output "config_file" {
  description = "Path of the generated config file."
  value       = local_file.config.filename
}
