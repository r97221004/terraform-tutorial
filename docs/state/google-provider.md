# Connecting to GCP

> Set up a GCP sandbox, then configure the google provider: project and region, default labels, aliases, and google vs. google-beta.

---

Everything so far ran on your own disk. From here on, Terraform creates real resources in GCP, through the **google provider**. Unlike `random` and `local`, it needs configuration: which project to work in, which region to default to, and whose credentials to use. This chapter configures it, and covers the provider features you only need once there's a cloud on the other end.

## Set up GCP

Do these once. Every GCP chapter after this one relies on them.

By the end of this section you'll have:

1. The **gcloud CLI** installed.
2. **Application Default Credentials (ADC)**, which is how Terraform logs in to GCP.
3. A dedicated **sandbox project**, linked to billing, used for nothing but this guide.
4. A **budget alert** on that project, created *before* any resources exist.
5. The base APIs enabled, and a few environment variables that every later chapter relies on.

### 1. Install the gcloud CLI

Terraform doesn't need gcloud to run, but you'll use gcloud to log in, create the project, and check what Terraform built. Commands assume Ubuntu, Debian, or WSL2, as in [Setup](../getting-started/setup.md).

```bash
# 1. Install the tools the next steps need
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates gnupg curl

# 2. Download Google Cloud's GPG key, used to verify the packages
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

# 3. Add Google Cloud's official apt repository
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
  | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

# 4. Refresh the package list so apt sees the new repository
sudo apt-get update

# 5. Install the gcloud CLI
sudo apt-get install -y google-cloud-cli

# 6. Check the version
gcloud version
```

On macOS and other platforms: [Install the gcloud CLI](https://cloud.google.com/sdk/docs/install).

Part 5 also needs `kubectl` and the GKE auth plugin. You'll install those when you get there.

### 2. Log in, twice

This is the step that confuses everyone. gcloud keeps **two separate sets of credentials**, and Terraform uses only one of them:

```mermaid
---
config:
  look: handDrawn
  theme: default
  themeVariables:
    fontFamily: '"Comic Sans MS", "Comic Sans", "Segoe Print", "Bradley Hand", cursive'
    lineColor: '#64748B'
    edgeLabelBackground: '#475569'
  themeCSS: |
    .edgeLabel, .edgeLabel p, .edgeLabel span { color: #FFFFFF !important; }
---
flowchart TB
    l1(["🔑 gcloud auth login"])
    l2(["🔑 gcloud auth application-default login"])
    c1["💻 credentials for the gcloud CLI<br/>gcloud storage ls · gcloud projects …"]
    c2[("📄 Application Default Credentials<br/>~/.config/gcloud/application_default_credentials.json")]
    tf["🛠️ Terraform google provider<br/>+ Google client libraries"]

    l1 --> c1
    l2 --> c2
    c2 ==>|"the only one Terraform reads"| tf

    classDef ctrl fill:#0F172A,stroke:#2563EB,stroke-width:2px,color:#FFFFFF
    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    classDef tgt fill:#0F172A,stroke:#16A34A,stroke-width:2px,color:#FFFFFF
    class l1,l2 ctrl
    class tf eng
    class c1,c2 tgt
```

Run both:

```bash
gcloud auth login                       # for the gcloud CLI
gcloud auth application-default login   # for Terraform (ADC)
```

Each opens a browser. On WSL2 or a remote machine where no browser opens, add `--no-launch-browser` and paste the URL it prints into a browser on your laptop.

If `gcloud` works but `terraform plan` says `could not find default credentials`, you skipped the second login. If both work but Terraform acts as the wrong account, run `gcloud auth application-default login` again. The two logins can point at different accounts without telling you.

> 🔑 **No service account keys.** Many older tutorials have you download a service account JSON key and set `GOOGLE_APPLICATION_CREDENTIALS`. Don't. A key is a long-lived password that ends up in Downloads folders, laptop backups, and Git history. In this guide you authenticate as yourself locally, and CI uses keyless Workload Identity Federation (see [CI/CD](../team-workflow/ci-cd.md)).

### 3. Create a sandbox project

Use a **brand-new project** for this guide. Then nothing you do can touch real workloads, IAM experiments stay contained, and if cleanup ever goes wrong you can delete the whole project as a last resort.

Project IDs are globally unique, 6–30 characters, lowercase letters, digits, and hyphens. Add a random suffix:

```bash
export PROJECT_ID="tf-tutorial-$(openssl rand -hex 3)"   # e.g. tf-tutorial-3fa9c1
gcloud projects create "$PROJECT_ID" --name="Terraform tutorial"
```

A project needs a **billing account** before it can create most resources. Find yours and link it:

```bash
gcloud billing accounts list
# ACCOUNT_ID            NAME                OPEN
# 0X0X0X-0X0X0X-0X0X0X  My Billing Account  True

export BILLING_ACCOUNT="0X0X0X-0X0X0X-0X0X0X"   # yours, from the list above
gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT"
```

Make it the default for gcloud, and tell ADC to bill API quota to it too:

```bash
gcloud config set project "$PROJECT_ID"
gcloud auth application-default set-quota-project "$PROJECT_ID"
```

> ⚠️ **Free trial accounts can't use GPUs.** The free trial credit covers Parts 2–4 easily, but GCP doesn't allow GPUs on free trial billing accounts. Before Part 5 you'll need to [upgrade to a paid account](https://cloud.google.com/free/docs/free-cloud-features#how-to-upgrade). Your remaining credit carries over. You'll also request GPU quota then. Both are covered in [GPU Node Pools](../ai-infra/gpu-node-pools.md).

### 4. Create a budget alert, now

Do this before creating any resource. A forgotten GKE cluster or GPU node is the classic way a learning project turns into a surprise bill.

```bash
gcloud services enable billingbudgets.googleapis.com

gcloud billing budgets create \
  --billing-account="$BILLING_ACCOUNT" \
  --display-name="tf-tutorial budget" \
  --budget-amount=20USD \
  --filter-projects="projects/$PROJECT_ID" \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
```

That emails the billing account's admins at 50%, 90%, and 100% of $20 spent in a month on this project. Change the amount to suit you, but keep the alert.

> 💡 **A budget is an alarm, not a brake.** It sends email; it does **not** stop or delete anything. Spending keeps going past 100% until you destroy the resources. That's why every chapter ends with a cleanup step, and why [Cleanup](../capstone/cleanup.md) ends by checking the bill.

If the command fails with `PERMISSION_DENIED`, your account isn't a Billing Account Administrator or Costs Manager on that billing account. Create the budget in the Console under **Billing → Budgets & alerts** instead, or ask whoever owns the billing account.

### 5. Enable the base APIs

Every GCP service is behind an API that must be enabled in the project before anything (gcloud, Terraform, or the Console) can use it. A new project starts with only a few enabled. Turn on the ones the first chapters need:

```bash
gcloud services enable \
  serviceusage.googleapis.com \
  cloudresourcemanager.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com
```

From [Projects & APIs](../gcp-foundations/projects-and-apis.md) onward, Terraform enables the APIs it needs itself, so this is the only time you do it by hand. `serviceusage` and `cloudresourcemanager` have to be enabled first, because they're the APIs Terraform uses to enable all the others.

### 6. Set the variables every chapter uses

Every GCP example from here on takes the project and region as input variables named `project_id` and `region`. Terraform automatically reads any environment variable named `TF_VAR_<name>`, so set them once per shell:

```bash
export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_region="us-central1"
```

`us-central1` is used throughout because it has broad GPU availability, including the L4 GPUs in Part 5. If you pick another region, check later that it offers the GPU type you want.

New shells won't have these variables. Add the three `export` lines (`PROJECT_ID`, `TF_VAR_project_id`, `TF_VAR_region`) to your `~/.bashrc`, or keep them in a small `env.sh` you `source` before each session.

### Verify

```bash
terraform version                                   # v1.11+
gcloud config get-value project                     # your tf-tutorial-xxxxxx project
gcloud auth application-default print-access-token > /dev/null && echo "ADC OK"
gcloud billing projects describe "$PROJECT_ID" --format='value(billingEnabled)'   # True
echo "$TF_VAR_project_id $TF_VAR_region"            # both set
```

If all five check out, you're ready to configure the provider.

## The example

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

- **`project`, `region`**: the defaults for resources that don't set their own. A resource can always override them, as the `dr` bucket below does with `location`. Both come from the `TF_VAR_project_id` and `TF_VAR_region` you exported in [step 6](#6-set-the-variables-every-chapter-uses).
- **`default_labels`**: labels applied to **every** resource this provider creates that supports labels, merged with the resource's own `labels`. It's the easiest way to make sure everything is labeled with its owner, environment, or cost center.
- **Credentials**: you don't set any. The provider finds your Application Default Credentials from [step 2](#2-log-in-twice) automatically. Never put credentials in a provider block. [IAM & Service Accounts](../gcp-foundations/iam.md) shows the one credential-related setting you will use, `impersonate_service_account`.

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
4. Your $20 budget reaches 100%. Does GCP stop the resources, and what actually stops compute charges?

<details>
<summary>Answer</summary>

1. Application Default Credentials: run `gcloud auth application-default login`. The provider reads credentials from the environment, never from the `provider` block, and the gcloud CLI's own login is a separate credential set.
2. It uses the default `google` configuration, which can place or read the resource in the wrong project or region.
3. No. Add `google-beta` only for features that require it, and keep the stable provider as the default.
4. No. A budget is an alert, not a spending cap. Destroying or stopping the billable resources, or deleting the dedicated sandbox project, stops new charges.

</details>

## Best practices

- **One sandbox project per learner or experiment.** Projects are free, and deleting one is the most complete cleanup there is.
- **Set a budget alert before creating anything.** Remember it only warns; destroying resources is what stops the cost.
- **Keep gcloud and ADC on the same account.** When Terraform does something unexpected, `gcloud auth list` and `gcloud auth application-default print-access-token` are the first things to check.
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
