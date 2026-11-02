# Connecting to GCP

> Configure the google provider and create your first cloud resource.

---

Everything so far ran on your own disk. From here on, Terraform creates real resources in GCP, through the **google provider**. Unlike `random` and `local`, it needs configuration: which project to work in, and which region to default to.

Finish [Set up GCP](gcp-setup.md) first. This chapter uses its project, its login, and the `TF_VAR_*` variables it had you export.

## The example

```bash
cd examples/state/google-provider
terraform init
```

This example creates one empty bucket, which costs nothing.

## Configuring the google provider

The `provider` block sets defaults for every resource that uses that provider. From [`providers.tf`](../../examples/state/google-provider/providers.tf):

```hcl
locals {
  # Every resource this provider creates gets these labels, on top of its own.
  default_labels = {
    managed-by = "terraform"
    tutorial   = "google-provider"
  }
}

provider "google" {
  project        = var.project_id
  region         = var.region
  default_labels = local.default_labels
}
```

- **`project`, `region`**: the defaults for resources that don't set their own. A resource can always override them. Both come from the `TF_VAR_project_id` and `TF_VAR_region` you exported in [Set up GCP](gcp-setup.md#6-set-the-variables-every-chapter-uses).
- **`default_labels`**: labels applied to **every** resource this provider creates that supports labels, merged with the resource's own `labels`. It's the easiest way to make sure everything is labeled with its owner, environment, or cost center.
- **Credentials**: you don't set any. The provider finds the Application Default Credentials from [Set up GCP](gcp-setup.md#2-log-in-twice) automatically. Never put credentials in a provider block.

The provider version is pinned in [`versions.tf`](../../examples/state/google-provider/versions.tf), exactly as in [Providers & Version Pinning](../core-language/providers.md): `~> 8.0`, with the lock file committed.

The bucket in [`main.tf`](../../examples/state/google-provider/main.tf) doesn't set `labels`, yet the plan shows it labeled:

```
  # google_storage_bucket.example will be created
  + resource "google_storage_bucket" "example" {
      + effective_labels            = {
          + "goog-terraform-provisioned" = "true"
          + "managed-by"                 = "terraform"
          + "tutorial"                   = "google-provider"
        }
      ...
```

`goog-terraform-provisioned` is added by the provider itself, so you can tell Terraform-managed resources apart in the Console.

## Apply it

```bash
terraform plan    # Plan: 1 to add, 0 to change, 0 to destroy.
terraform apply
gcloud storage buckets list --filter="labels.tutorial=google-provider" --format="table(name,location)"
```

The bucket shows up with the `tutorial=google-provider` label, even though its resource block doesn't set it.

## Checkpoint

1. `terraform plan` fails with `could not find default credentials`. Why doesn't adding settings to the `provider` block fix it?
2. A bucket sets no `labels`. Which labels does it end up with, and where does each come from?
3. Why are `project` and `region` set from variables instead of written into the `provider` block?

<details>
<summary>Answer</summary>

1. The provider reads credentials from the environment, never from the `provider` block. Run `gcloud auth application-default login` to create Application Default Credentials.
2. `managed-by` and `tutorial`, from the provider's `default_labels`, plus `goog-terraform-provisioned`, which the provider adds itself.
3. So the same code runs unchanged in every sandbox and environment. Only the `TF_VAR_*` values differ.

</details>

## Best practices

- **Set `project` and `region` from variables**, never hard-coded, so the same code runs in every sandbox and environment.
- **Set `default_labels`** on every google provider configuration, so nothing goes unlabeled.
- **Keep credentials out of `provider` blocks.** Use ADC locally and Workload Identity Federation in CI.

## Clean up

```bash
terraform destroy
```

---

[← Set up GCP](gcp-setup.md) · [↑ Contents](../../README.md) · [State & Drift →](state-basics.md)
