# The finished configuration from Core Workflow, after step 5.

resource "random_pet" "name" {}

resource "local_file" "greeting" {
  filename = "hello.txt"
  content  = "Hello, ${random_pet.name.id}!"
}

output "pet_name" {
  value = random_pet.name.id
}
