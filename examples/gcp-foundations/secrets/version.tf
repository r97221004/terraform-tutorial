# OPTIONAL: let Terraform set the secret's value WITHOUT storing it.
#
#   export TF_VAR_hf_token="hf_..."        # from your password manager
#   terraform apply -var hf_token_version=1
#
# secret_data_wo is write-only: it's sent to GCP but never saved in state
# or in a plan file. Terraform can't tell when the value changes, so you
# bump hf_token_version to tell it to write a new one.

resource "google_secret_manager_secret_version" "hf_token" {
  count = var.hf_token_version > 0 ? 1 : 0

  secret                 = google_secret_manager_secret.hf_token.id
  secret_data_wo         = var.hf_token
  secret_data_wo_version = var.hf_token_version
}
