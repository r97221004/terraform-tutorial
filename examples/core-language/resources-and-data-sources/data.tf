# Data sources READ things that already exist. Terraform never creates,
# changes, or deletes them.

# The project this configuration runs in (the provider's default project).
# Gives us its number, which many GCP APIs and service agents use.
data "google_project" "this" {}

# Who is running Terraform right now (the account behind your ADC).
data "google_client_openid_userinfo" "me" {}

# The Google-managed service agent that Cloud Storage uses in this project.
# You grant it roles when buckets need to use your KMS keys or publish
# notifications. GCP creates it; you only look it up.
data "google_storage_project_service_account" "gcs" {}
