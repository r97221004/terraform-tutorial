# Each resource type starts with the local name of the provider that manages it:
# random_pet comes from `random`, local_file from `local`.
resource "random_pet" "server" {
  length = 2
}

resource "local_file" "server" {
  filename             = "${path.module}/out/server.txt"
  content              = "${random_pet.server.id}\n"
  file_permission      = "0644"
  directory_permission = "0755"
}
