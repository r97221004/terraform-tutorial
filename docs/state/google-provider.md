# Connecting to GCP

> The google provider: project and region, default labels, aliases, and google vs. google-beta.

---

Everything so far ran on your own disk. From here on, Terraform creates real resources in GCP, through the **google provider**. Unlike `random` and `local`, it needs configuration: which project to work in, which region to default to, and whose credentials to use. This chapter configures it, and covers the provider features you only need once there's a cloud on the other end.

## Before you start

You need a GCP sandbox project and credentials. If you haven't done these yet, complete [Setup](../getting-started/setup.md) from [step 2](../getting-started/setup.md#2-install-the-gcloud-cli) on: the gcloud CLI, both logins, a sandbox project with billing, a budget alert, the base APIs, and the `TF_VAR_*` variables. Then check:

```bash
echo "$TF_VAR_project_id $TF_VAR_region"   # e.g. tf-tutorial-3fa9c1 us-central1
gcloud auth application-default print-access-token > /dev/null && echo "ADC OK"
```

```bash
cd examples/state/google-provider
terraform init
```

This example creates three small buckets: one in your default region, one in a second "disaster recovery" region, and one through the `google-beta` provider. Empty buckets cost nothing.

## Configuring the google provider

The `provider` block sets defaults for every resource that uses that provider. From [`providers.tf`](../../examples/state/google-provider/providers.tf):

```hcl
locals {
  # Every resource either provider creates gets these labels, on top of its own.
  default_labels = {
    managed-by = "terraform"
    tutorial   = "providers"
  }
}

# The default google provider: used by any google_* resource that doesn't say otherwise.
provider "google" {
  project        = var.project_id
  region         = var.region
  default_labels = local.default_labels
}
```

- **`project`, `region`**: the defaults for resources that don't set their own. A resource can always override them, as the `dr` bucket below does with `location`. Both come from the `TF_VAR_project_id` and `TF_VAR_region` you exported in Setup.
- **`default_labels`**: labels applied to **every** resource this provider creates that supports labels, merged with the resource's own `labels`. It's the easiest way to make sure everything is labeled with its owner, environment, or cost center.
- **Credentials**: you don't set any. The provider finds your Application Default Credentials from [Setup](../getting-started/setup.md#3-log-in-twice) automatically. Never put credentials in a provider block. [IAM & Service Accounts](../gcp-foundations/iam.md) shows the one credential-related setting you will use, `impersonate_service_account`.

The provider versions are pinned in [`versions.tf`](../../examples/state/google-provider/versions.tf), exactly as in [Providers & Version Pinning](../core-language/providers.md): `~> 8.0` for both `google` and `google-beta`, with the lock file committed.

None of the buckets in `main.tf` sets `labels`, yet the plan shows them labeled:

```
  # google_storage_bucket.primary will be created
  + resource "google_storage_bucket" "primary" {
      + effective_labels            = {
          + "goog-terraform-provisioned" = "true"
          + "managed-by"                 = "terraform"
          + "tutorial"                   = "providers"
        }
      ...
```

`goog-terraform-provisioned` is added by the provider itself, so you can tell Terraform-managed resources apart in the Console.

## Two configurations of one provider: `alias`

Sometimes one configuration needs the same provider set up two ways: two regions, two projects, or two sets of credentials. Add a second `provider` block with an **`alias`**:

```hcl
# A second configuration of the SAME provider, for another region.
# Resources opt in with `provider = google.dr`.
provider "google" {
  alias          = "dr"
  project        = var.project_id
  region         = var.dr_region
  default_labels = local.default_labels
}
```

The block without an alias is the **default** configuration. A resource uses the aliased one only when it asks, with the `provider` meta-argument:

```hcl
resource "google_storage_bucket" "dr" {
  provider = google.dr     # <local name>.<alias>, not a string

  name     = "${var.project_id}-providers-dr"
  location = var.dr_region
  ...
}
```

```
Changes to Outputs:
  + buckets = {
      + beta    = "US-CENTRAL1"
      + dr      = "US-EAST1"
      + primary = "US-CENTRAL1"
    }
```

Common uses of `alias` in GCP:

- **A second project**: a shared "network host" project alongside a workload project, or a central logging project.
- **A second region**: disaster-recovery copies, or regional resources such as Artifact Registry repositories in several places.
- **Different credentials**: one configuration impersonating a deploy service account, another impersonating a read-only one.

> 💡 For a bucket, `location` alone decides where it lives, so the alias is only demonstrating the mechanism here. It matters for resources that have no location argument of their own and take the region from the provider, and for working across projects.

## `google` vs. `google-beta`

GCP releases many features in **preview** before they're generally available. The google provider ships as **two providers** built from the same code:

| | `google` | `google-beta` |
|---|---|---|
| Features | generally available (GA) only | GA **plus** preview (beta) features |
| Stability | GA features follow normal deprecation rules | preview features can change or disappear |
| Versions | released together, with the same version numbers | |
| Use it | by default, for everything | only for resources or arguments that need a preview feature |

A resource that needs a preview feature opts in exactly like an alias:

```hcl
resource "google_storage_bucket" "beta" {
  provider = google-beta
  ...
}
```

Rules that keep this manageable:

- **Default to `google`.** Switch individual resources to `google-beta` only when the docs mark an argument or resource as beta. The Registry pages say so explicitly.
- **Configure both identically** (same project, region, `default_labels`), or the resources they manage will behave inconsistently.
- **Pin both to the same version range.** They're released in lockstep, and mixing `google` 8.7 with `google-beta` 8.3 just causes confusion.
- **Switching back is free.** When a feature reaches GA, change `provider = google-beta` back to the default. The resource stays the same; only the provider that manages it changes. Run `plan` to confirm there's nothing else to do.

## Apply it

```bash
terraform plan    # Plan: 3 to add, 0 to change, 0 to destroy.
terraform apply
gcloud storage buckets list --filter="labels.tutorial=providers" --format="table(name,location)"
```

All three buckets show up with the `tutorial=providers` label, even though none of them sets it.

## Checkpoint

1. `terraform plan` works with `gcloud` logged in, but fails with `could not find default credentials`. What's missing, and why doesn't the provider block fix it?
2. A resource must use the `google.dr` provider alias. What happens if its `provider = google.dr` line is omitted?
3. Should every configuration declare both `google` and `google-beta` just in case?

<details>
<summary>Answer</summary>

1. Application Default Credentials: run `gcloud auth application-default login`. The provider reads credentials from the environment, never from the `provider` block, and the gcloud CLI's own login is a separate credential set.
2. It uses the default `google` configuration, which can place or read the resource in the wrong project or region.
3. No. Add `google-beta` only for features that require it, and keep the stable provider as the default.

</details>

## Best practices

- **Set `project` and `region` from variables**, never hard-coded, so the same code runs in every sandbox and environment.
- **Set `default_labels`** on every google provider configuration, so nothing goes unlabeled.
- **Keep credentials out of `provider` blocks.** Use ADC locally and Workload Identity Federation in CI.
- **Prefer `google`; use `google-beta` per resource**, only where a preview feature requires it, and configure and pin both identically.

## Clean up

```bash
terraform destroy
```

---

[← Meta-Arguments](../core-language/meta-arguments.md) · [↑ Contents](../../README.md) · [State & Drift →](state-basics.md)
