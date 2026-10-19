# Variables, Locals & Outputs

> Inputs, computed values, and results: tfvars, validation, and sensitive values.

---

Hard-coded configurations work once. To use the same code for `dev` and `prod`, for your project and a teammate's, you need three things: **input variables** to take values in, **locals** to name values you compute, and **outputs** to hand results back out. Together they're the interface of every Terraform configuration, and later of every module you write.

## Before you start

```bash
cd examples/core-language/variables-and-outputs
cp terraform.tfvars.example terraform.tfvars
terraform init
```

The example creates a bucket for model weights. Its name, labels, and settings all come from variables, so the same code can serve any environment or team.

## How the three fit together

```mermaid
---
config:
  look: handDrawn
  theme: default
  themeVariables:
    fontFamily: '"Comic Sans MS", "Comic Sans", "Segoe Print", "Bradley Hand", cursive'
    lineColor: '#FFFFFF'
    edgeLabelBackground: '#475569'
  themeCSS: |
    .edgeLabel, .edgeLabel p, .edgeLabel span { color: #FFFFFF !important; }
---
flowchart LR
    caller(["🧑‍💻 you, CI,<br/>or a calling module"])
    var["📥 variables<br/>var.environment"]
    loc["🧮 locals<br/>local.bucket_name"]
    res["🧱 resources<br/>google_storage_bucket.models"]
    out["📤 outputs<br/>bucket_url"]

    caller -->|"tfvars · -var · TF_VAR_"| var
    var --> loc
    var --> res
    loc --> res
    res --> out
    loc --> out
    out -->|"terraform output"| caller

    classDef ctrl fill:#0F172A,stroke:#2563EB,stroke-width:2px,color:#FFFFFF
    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    classDef tgt fill:#0F172A,stroke:#16A34A,stroke-width:2px,color:#FFFFFF
    class caller tgt
    class var,loc,out ctrl
    class res eng
```

| | Declared with | Referred to as | Set by |
|---|---|---|---|
| Input variable | `variable "environment" { }` | `var.environment` | the caller |
| Local value | `locals { bucket_name = ... }` | `local.bucket_name` | the configuration itself |
| Output | `output "bucket_url" { }` | `terraform output bucket_url`, or `module.<name>.bucket_url` | the configuration itself |

## Input variables

### Declaring a variable

From [`variables.tf`](../../examples/core-language/variables-and-outputs/variables.tf):

```hcl
variable "environment" {
  description = "Deployment environment. Becomes part of names and labels."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}
```

| Argument | What it does |
|---|---|
| `description` | Shown when Terraform prompts for a value, and by documentation tools. Always write one. |
| `type` | The accepted type. Values are converted to it, and anything that doesn't fit is rejected before planning starts. |
| `default` | Makes the variable **optional**. Without a default, the variable is **required**. |
| `validation` | A custom rule with your own error message. You can have several. |
| `sensitive` | Hides the value in plan and apply output. See [Sensitive values](#sensitive-values). |
| `nullable` | `false` means the caller can't pass `null`. Mostly useful in modules. |
| `ephemeral` | The value is never written to state or plan files. Covered in [Secret Manager & Sensitive Values](../gcp-foundations/secrets.md). |

**Required or optional?** Give a default only when there's a value that's right for most callers, like `region = "us-central1"`. Leave it off when a wrong guess would be dangerous. Here `environment` and `team` have no default, so nobody accidentally creates a "dev" bucket in production.

If a required variable has no value, Terraform asks for it:

```
var.environment
  Deployment environment. Becomes part of names and labels.

  Enter a value:
```

In CI, where nobody is there to type, use `-input=false` and the same situation becomes an error:

```
Error: No value for required variable

  on variables.tf line 12:
  12: variable "environment" {

The root module input variable "environment" is not set, and has no default
value. Use a -var or -var-file command line argument to provide a value for
this variable.
```

### Types for structured input

Simple values use `string`, `number`, `bool`, `list(string)`, or `map(string)`:

```hcl
variable "extra_labels" {
  description = "Additional labels to put on every resource."
  type        = map(string)
  default     = {}
}
```

When several settings belong together, use an **`object`** with **`optional()`** fields. Callers set only what they care about, and every field they leave out gets its default:

```hcl
variable "model_bucket" {
  description = "Settings for the model-weights bucket. Every field is optional."
  type = object({
    name_suffix          = optional(string, "models")
    storage_class        = optional(string, "STANDARD")
    versioning           = optional(bool, true)
    old_versions_to_keep = optional(number, 3)
  })
  default = {}
  ...
}
```

The example's `terraform.tfvars` sets only two of the four fields:

```hcl
model_bucket = {
  storage_class        = "STANDARD"
  old_versions_to_keep = 5
  # name_suffix and versioning are left out: their optional() defaults apply.
}
```

`terraform console` shows the value Terraform actually uses:

```
> var.model_bucket
{
  "name_suffix" = "models"
  "old_versions_to_keep" = 5
  "storage_class" = "STANDARD"
  "versioning" = true
}
```

Type checks catch mistakes before anything is planned:

```bash
terraform plan -var 'model_bucket={old_versions_to_keep="five"}'
```

```
Error: Invalid value for input variable

  on variables.tf line 33:
  33: variable "model_bucket" {

Unsuitable value for var.model_bucket set using -var="model_bucket=...": a
number is required.
```

> ⚠️ **Misspelled fields are silently dropped.** Passing `model_bucket = { storage = "COLDLINE" }` (instead of `storage_class`) is **not** an error. Converting to the object type discards attributes it doesn't know, so you get `STANDARD` and no warning. Check the plan, or `terraform console`, when an object setting seems to be ignored.

### Validation rules

`type` checks shape; `validation` checks meaning. The `condition` must be `true` for the value to be accepted:

```hcl
variable "team" {
  description = "Owning team, used as a label value."
  type        = string

  validation {
    # GCP label values: lowercase letters, digits, - and _, at most 63 characters.
    condition     = can(regex("^[a-z0-9_-]{1,63}$", var.team))
    error_message = "team must be 1-63 characters: lowercase letters, digits, - or _."
  }
}
```

```bash
terraform plan -var 'team=ML Platform'
```

```
Error: Invalid value for variable

  on variables.tf line 22:
  22: variable "team" {
    ├────────────────
    │ var.team is "ML Platform"

team must be 1-63 characters: lowercase letters, digits, - or _.

This was checked by the validation rule at variables.tf:26,3-13.
```

Without the rule, this value would get through `plan` and fail halfway through `apply` with an API error about label values. Validation moves the failure to the earliest point, with a message that says how to fix it. Good candidates are anything GCP is strict about: names, label values, region lists, allowed machine or GPU types.

`can(...)` turns an error into `false`, which is how `regex` (which fails when nothing matches) becomes a condition. More functions are in [Expressions & Functions](expressions.md).

### Setting values, and which one wins

Terraform reads variable values from several places. When the same variable is set in more than one, **the later source in this list wins**:

```mermaid
---
config:
  look: handDrawn
  theme: default
  themeVariables:
    fontFamily: '"Comic Sans MS", "Comic Sans", "Segoe Print", "Bradley Hand", cursive'
    lineColor: '#FFFFFF'
    edgeLabelBackground: '#475569'
  themeCSS: |
    .edgeLabel, .edgeLabel p, .edgeLabel span { color: #FFFFFF !important; }
---
flowchart LR
    d["1️⃣ default<br/>in variables.tf"]
    e["2️⃣ TF_VAR_name<br/>environment variable"]
    t["3️⃣ terraform.tfvars"]
    a["4️⃣ *.auto.tfvars<br/>alphabetical order"]
    c["5️⃣ -var-file and -var<br/>in command-line order"]

    d -->|"overridden by"| e
    e -->|"overridden by"| t
    t -->|"overridden by"| a
    a -->|"overridden by"| c

    classDef ctrl fill:#0F172A,stroke:#2563EB,stroke-width:2px,color:#FFFFFF
    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    classDef tgt fill:#0F172A,stroke:#16A34A,stroke-width:2px,color:#FFFFFF
    class d tgt
    class e,t,a ctrl
    class c eng
```

You can watch it happen, with `terraform.tfvars` setting `environment = "dev"`:

```bash
echo 'var.environment' | TF_VAR_environment=staging terraform console
# "dev"       terraform.tfvars beats TF_VAR_

echo 'environment = "staging"' > staging.tfvars
echo 'var.environment' | terraform console -var-file=staging.tfvars
# "staging"   -var-file beats terraform.tfvars

echo 'var.environment' | terraform console -var-file=staging.tfvars -var environment=prod
# "prod"      the last command-line argument wins
```

How each source is typically used:

| Source | Typical use |
|---|---|
| `default` | a sensible value for most callers |
| `TF_VAR_project_id` | per-person or per-shell values, like your sandbox project (from [Setup](../getting-started/setup.md)) |
| `terraform.tfvars` | this directory's values. Loaded automatically. **Git-ignored** in this repo |
| `*.auto.tfvars` | also loaded automatically. Handy when a tool generates a values file |
| `-var-file=prod.tfvars` | choosing an environment's values explicitly. [Environments](../modules/environments.md) builds on this |
| `-var 'name=value'` | one-off overrides while experimenting |

Why is `terraform.tfvars` git-ignored? It tends to hold project IDs, and sometimes secrets, specific to one person or environment. The repo commits a **`terraform.tfvars.example`** instead, documenting what to set:

```hcl
# Copy to terraform.tfvars (git-ignored) and edit:
#   cp terraform.tfvars.example terraform.tfvars
#
# project_id and region come from TF_VAR_project_id / TF_VAR_region (see Setup).

environment = "dev"
team        = "ml-platform"
...
```

Teams often do commit non-secret per-environment files like `envs/prod.tfvars`, since they're reviewed configuration, not personal settings. That's a choice you make on purpose, covered in [Environments](../modules/environments.md).

## Locals

A **local value** names an expression so you can use it in many places, and change it in one. From [`main.tf`](../../examples/core-language/variables-and-outputs/main.tf):

```hcl
locals {
  # Name things once, use the names everywhere.
  name_prefix = "${var.project_id}-${var.environment}"
  bucket_name = "${local.name_prefix}-${var.model_bucket.name_suffix}"

  # Labels every resource gets (applied through the provider's default_labels).
  # Keys in extra_labels can't override these, because these come last.
  labels = merge(var.extra_labels, {
    environment = var.environment
    team        = var.team
    managed-by  = "terraform"
  })
}
```

- The block is `locals` (plural); a reference is `local.<name>` (singular).
- Locals can refer to variables, resources, data sources, and other locals, in any order. Terraform works out the dependencies.
- **Callers can't set a local.** That's the difference from a variable: a variable is part of your interface, a local is an implementation detail.

`local.labels` is used as the provider's `default_labels` in [`providers.tf`](../../examples/core-language/variables-and-outputs/providers.tf), so every resource gets it:

```
      + effective_labels            = {
          + "cost-center"                = "research"
          + "environment"                = "dev"
          + "goog-terraform-provisioned" = "true"
          + "managed-by"                 = "terraform"
          + "team"                       = "ml-platform"
        }
```

**When to use a local:**

- The same expression appears in two or more places: names, labels, prefixes.
- An expression is long enough that a name makes the resource easier to read.
- You want one place to change a convention, such as the naming scheme.

**When not to:** wrapping a single `var.region` in `local.region` only adds a hop for the reader. If a value is used once and is short, write it inline.

## Outputs

An **output** exposes a value after `apply`. From [`outputs.tf`](../../examples/core-language/variables-and-outputs/outputs.tf):

```hcl
output "bucket_url" {
  description = "gs:// URL of the model-weights bucket, for training and serving jobs."
  value       = google_storage_bucket.models.url
}

output "model_bucket_settings" {
  description = "The model_bucket variable after optional() defaults were filled in."
  value       = var.model_bucket
}
```

Outputs have three audiences:

- **You**, after `apply`: the values you'd otherwise go to the Console for.
- **Scripts and CI**, through `terraform output`: a deploy job reads the bucket URL instead of hard-coding it.
- **Other Terraform code**: a module's outputs are its return values (`module.storage.bucket_url`), as you'll see in [Writing Modules](../modules/writing-modules.md).

They're printed at the end of every `apply`, and shown as changes in the plan:

```
Changes to Outputs:
  + bucket_name           = "tf-tutorial-3fa9c1-dev-models"
  + bucket_url            = (known after apply)
  + labels                = {
      + cost-center = "research"
      + environment = "dev"
      + managed-by  = "terraform"
      + team        = "ml-platform"
    }
  + model_bucket_settings = {
      + name_suffix          = "models"
      + old_versions_to_keep = 5
      + storage_class        = "STANDARD"
      + versioning           = true
    }
```

### Reading outputs: `terraform output`

```bash
terraform output                     # all outputs, human-readable
terraform output bucket_name         # one output, as an HCL value: "tf-tutorial-3fa9c1-dev-models"
terraform output -raw bucket_name    # one string, no quotes: for shell scripts
terraform output -json labels        # one output as JSON: for jq and other tools
```

```
$ terraform output -json labels
{"cost-center":"research","environment":"dev","managed-by":"terraform","team":"ml-platform"}
```

Use `-raw` for single strings in shell commands, as you did with `gcloud storage cat "$(terraform output -raw readme_uri)"` in [Anatomy of HCL](../getting-started/hcl-anatomy.md). Use `-json` for anything structured. Outputs are read from **state**, so they only exist after an `apply`, and they don't call GCP.

**What makes a good output:** values someone downstream needs (names, URLs, IDs, service account emails), each with a `description`. Don't output whole resources "just in case". Every output is a promise to its readers, and removing one later can break them.

## Sensitive values

Some values shouldn't appear on screen or in CI logs: API tokens, passwords, private keys. Terraform tracks **sensitivity** on values, and hides sensitive ones in plan and apply output as `(sensitive value)`.

Values become sensitive in two ways:

- **The provider marks an attribute sensitive.** That's why `google_storage_bucket_object`'s `content` showed as `(sensitive value)` in [Anatomy of HCL](../getting-started/hcl-anatomy.md): the provider can't know whether a file's contents are secret, so it assumes they might be.
- **You mark a variable or output** with `sensitive = true`.

Sensitivity **follows the value**. Anything computed from a sensitive value is sensitive too, and Terraform won't let it leak out through an unmarked output:

```hcl
variable "hf_token" {
  type      = string
  sensitive = true
}

output "token_preview" {
  value = "token is ${var.hf_token}"
}
```

```
Error: Output refers to sensitive values

  on main.tf line 5:
   5: output "token_preview" {

To reduce the risk of accidentally exporting sensitive data that was intended
to be only internal, Terraform requires that any root module output
containing sensitive data be explicitly marked as sensitive, to confirm your
intent.

If you do intend to export this data, annotate the output value as sensitive
by adding the following argument:
    sensitive = true
```

With `sensitive = true` on the output, it's shown as `<sensitive>` in the summary, but asking for it by name reveals it:

```
$ terraform output
hf_token = <sensitive>

$ terraform output -raw hf_token
hf_abc123
```

> 🔐 **`sensitive` hides values from the screen, not from state.** The plain value is still written to `terraform.tfstate`:
>
> ```
> $ grep hf_abc123 terraform.tfstate
>       "value": "hf_abc123",
> ```
>
> Anyone who can read your state can read every secret in it. That's why state lives in a locked-down bucket ([Remote Backend](../state/remote-backend.md)), and why the right answer for real secrets is to keep them **out of Terraform values entirely**: store them in Secret Manager and have workloads read them at runtime, or use `ephemeral` variables and write-only arguments, which are never saved. [Secret Manager & Sensitive Values](../gcp-foundations/secrets.md) covers both.

## Apply it

```bash
terraform plan     # Plan: 1 to add, 0 to change, 0 to destroy.
terraform apply
terraform output
gcloud storage buckets describe "$(terraform output -raw bucket_url)" --format="yaml(name,default_storage_class,labels)"
```

Then try another environment without touching the files, and read the plan. Changing `environment` changes the bucket's name, so the plan is a replacement:

```bash
terraform plan -var environment=staging
```

```
  # google_storage_bucket.models must be replaced
-/+ resource "google_storage_bucket" "models" {
      ...
      ~ name                        = "tf-tutorial-3fa9c1-dev-models" -> "tf-tutorial-3fa9c1-staging-models" # forces replacement
      ...

Plan: 1 to add, 0 to change, 1 to destroy.
```

That's not how you'd run two environments for real: both would share one state, so switching would destroy the other. [Environments](../modules/environments.md) shows the right way.

## Best practices

- **Give every variable a `description` and a `type`.** They're your configuration's documentation, and `type` catches mistakes before planning.
- **No default for values that are dangerous to guess**: environment, project, anything that names production.
- **Validate what GCP is strict about**, so bad input fails at `plan` with your message instead of mid-`apply` with an API error.
- **Group related settings into an `object` with `optional()` defaults** rather than many loose variables. Remember that unknown fields are dropped silently.
- **Commit `terraform.tfvars.example`, not `terraform.tfvars`.**
- **Use locals for names and labels**, so the convention lives in one place.
- **Output what downstream needs, with descriptions.** Use `-raw` and `-json` in scripts.
- **Treat `sensitive` as screen protection only.** Secrets in Terraform values end up in state; keep real secrets out, as shown in [Secrets](../gcp-foundations/secrets.md).

## Clean up

```bash
terraform destroy
```

---

[← Resources & Data Sources](resources-and-data-sources.md) · [↑ Contents](../../README.md) · [Expressions & Functions →](expressions.md)
