# Data sources READ things that already exist. Terraform never creates,
# changes, or deletes them.

# A file this configuration doesn't own: picture another team's tooling
# writing it. Terraform reads it again on every plan.
data "local_file" "team" {
  filename = "${path.module}/input/team.json"
}
