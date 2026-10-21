# Testing & Code Quality

> fmt, validate, tflint, terraform test, check blocks, and preconditions.

---

A `plan` review catches a lot, but only after someone has written the change, pushed it, and someone else has read a long diff. Cheaper checks catch whole classes of mistakes earlier: formatting, typos, invalid machine types, broken module logic. This chapter stacks them from fastest to slowest, and runs every one of them for real.

## Before you start

```bash
cd examples/team-workflow/testing-and-quality
terraform init
```

The example is a small module, a model-weights bucket whose settings depend on the environment, with unit tests in `tests/` and a tflint configuration.

## The layers

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
flowchart LR
    fmt["🧹 fmt<br/>style"]
    val["✅ validate<br/>syntax, types"]
    lint["🔎 tflint<br/>provider rules, conventions"]
    test["🧪 terraform test<br/>module logic"]
    sec["🛡️ security scan<br/>misconfigurations"]
    plan["📋 plan review<br/>the real diff"]

    fmt --> val --> lint --> test --> sec --> plan

    classDef ctrl fill:#0F172A,stroke:#2563EB,stroke-width:2px,color:#FFFFFF
    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    classDef tgt fill:#0F172A,stroke:#16A34A,stroke-width:2px,color:#FFFFFF
    class fmt,val,lint ctrl
    class test,sec eng
    class plan tgt
```

| Check | Needs credentials? | Time | Catches |
|---|---|---|---|
| `terraform fmt -check` | no | instant | inconsistent formatting |
| `terraform validate` | no | seconds | syntax errors, wrong types, unknown arguments, missing references |
| `tflint` | no | seconds | invalid machine types and regions, unused variables, missing version pins |
| `terraform test` (plan + mocks) | no | seconds | broken module logic: names, conditionals, `for_each`, validations |
| security scan | no | seconds | public buckets, missing encryption, broad IAM ([next chapter](security-scanning.md)) |
| `terraform plan` | yes | minutes | everything that depends on the real world: drift, replacements |

Everything above the line `plan` runs without a GCP account, which means it can run on every commit, in seconds, in CI for every pull request.

## `fmt` and `validate`

```bash
terraform fmt -check -recursive   # exit 3 and list files that need formatting
terraform fmt -recursive          # fix them
terraform validate
```

`validate` needs `terraform init` first, but not credentials: in CI, `terraform init -backend=false` installs providers and modules without touching the state bucket. It checks that the configuration is internally consistent: arguments exist, types match, references resolve. It doesn't know what values GCP accepts. That's the next layer.

## `tflint`: rules `validate` doesn't know

[TFLint](https://github.com/terraform-linters/tflint) is a linter with plugins per provider. The [google ruleset](https://github.com/terraform-linters/tflint-ruleset-google) knows things like the valid machine types and regions. Configuration lives in [`.tflint.hcl`](../../examples/team-workflow/testing-and-quality/.tflint.hcl):

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "google" {
  enabled = true
  version = "0.40.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}
```

```bash
tflint --init     # download the plugins in .tflint.hcl
tflint            # lint the current directory
```

Here's a configuration that `terraform validate` accepts without complaint:

```hcl
variable "unused" {
  type = string
}

resource "google_compute_instance" "debug" {
  name         = "debug-vm"
  machine_type = "n2-standard-3"
  ...
}
```

tflint doesn't:

```
2 issue(s) found:

Warning: [Fixable] variable "unused" is declared but not used (terraform_unused_declarations)

  on main.tf line 5:
   5: variable "unused" {

Error: "n2-standard-3" is an invalid as machine type (google_compute_instance_invalid_machine_type)

  on main.tf line 11:
  11:   machine_type = "n2-standard-3"
```

There's no `n2-standard-3`; without tflint, you'd find out from an API error halfway through an apply. tflint exits non-zero when it finds issues, so it can fail a CI job.

Lint a whole repository with `tflint --recursive`. Run against every example in this guide, it flagged one file: `state/refactoring/refactored/main.tf`, which is meant to be copied over another file and has no `terraform` block of its own. For deliberate exceptions, tflint takes annotations in the code:

```hcl
# tflint-ignore-file: terraform_required_providers, terraform_required_version
```

`# tflint-ignore: rule_name` on the line above a block ignores one occurrence. Like every suppression, leave a comment saying why.

## `terraform test`: unit tests for modules

[`terraform test`](https://developer.hashicorp.com/terraform/language/tests) runs `*.tftest.hcl` files from the `tests/` directory. Each **`run`** block plans (or applies) the module with given variables, then checks **`assert`** conditions against the result.

The module under test, from [`main.tf`](../../examples/team-workflow/testing-and-quality/main.tf), has rules worth protecting:

```hcl
locals {
  is_prod = var.environment == "prod"
}

resource "google_storage_bucket" "models" {
  project  = var.project_id
  name     = "${var.project_id}-models-${var.environment}"
  location = var.region
  ...
  force_destroy = !local.is_prod

  soft_delete_policy {
    # prod keeps deleted weights for 7 days; other environments don't pay for it.
    retention_duration_seconds = local.is_prod ? 604800 : 0
  }
}
```

The tests, from [`tests/unit.tftest.hcl`](../../examples/team-workflow/testing-and-quality/tests/unit.tftest.hcl):

```hcl
# Unit tests: plan only, against a mocked provider. No credentials, no
# cloud resources, runs in seconds. `terraform test` runs every *.tftest.hcl.

mock_provider "google" {}

variables {
  project_id = "test-project"
  region     = "us-central1"
  gpu_region = "us-central1"
}

run "prod_bucket_is_protected" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = google_storage_bucket.models.force_destroy == false
    error_message = "prod buckets must never be force-destroyed."
  }

  assert {
    condition     = google_storage_bucket.models.soft_delete_policy[0].retention_duration_seconds == 604800
    error_message = "prod buckets must keep deleted objects for 7 days."
  }
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  # The test passes only if this validation fails.
  expect_failures = [var.environment]
}
```

- **`mock_provider "google" {}`** replaces the real provider with one that never calls GCP. Computed attributes get fake values. Tests need no credentials and create nothing.
- **`command = plan`** checks what the module *would* do. Most module logic (names, conditionals, `for_each`, labels) is fully visible in the plan.
- **Top-level `variables`** apply to every run; each run can add or override its own.
- **`expect_failures`** turns a failure into the expected outcome: here, that the `environment` validation rejects `qa`.

```bash
terraform test
```

```
tests/unit.tftest.hcl... in progress
  run "dev_bucket_is_disposable"... pass
  run "prod_bucket_is_protected"... pass
  run "readers_get_one_grant_each"... pass
  run "rejects_unknown_environment"... pass
tests/unit.tftest.hcl... tearing down
tests/unit.tftest.hcl... pass

Success! 4 passed, 0 failed.
```

Now break the rule: someone "simplifies" the soft delete line to `retention_duration_seconds = 0`. The plan for dev looks fine, and the change is easy to wave through in review. The test isn't fooled:

```
  run "prod_bucket_is_protected"... fail

Error: Test assertion failed

  on tests/unit.tftest.hcl line 48, in run "prod_bucket_is_protected":
  48:     condition     = google_storage_bucket.models.soft_delete_policy[0].retention_duration_seconds == 604800
    ├────────────────
    │ Diff:
    │ --- actual
    │ +++ expected
    │ - 0
    │ + 604800


prod buckets must keep deleted objects for 7 days.
...
Failure! 3 passed, 1 failed.
```

`terraform test` exits non-zero on failure, so CI blocks the merge.

### Integration tests

A `run` with `command = apply` (the default) creates **real** resources with the real provider, asserts against their actual attributes, and destroys them when the test file finishes. That catches what mocks can't, such as an API rejecting a combination of settings, at the cost of credentials, minutes, and money. Run them nightly, in a dedicated test project, rather than on every commit.

## Assertions inside the configuration

Tests check modules before merge. Three kinds of conditions check **every** plan and apply, in production too:

| Mechanism | Checks | On failure | Covered in |
|---|---|---|---|
| `validation` in a `variable` | one input value | error, before planning | [Variables, Locals & Outputs](../core-language/variables-and-outputs.md#validation-rules) |
| `precondition` / `postcondition` in `lifecycle` | assumptions about a resource, before/after it changes | error, stops the operation | [Meta-Arguments](../core-language/meta-arguments.md#precondition-and-postcondition-assumptions-checked) |
| **`check` block** | anything, about the whole configuration | **warning**; nothing stops | here |

A `check` block is for "this works, but it's probably a mistake". The example warns when the weights bucket isn't in the GPUs' region:

```hcl
check "weights_next_to_gpus" {
  assert {
    condition     = lower(var.region) == lower(var.gpu_region)
    error_message = "The models bucket (${var.region}) isn't in the GPUs' region (${var.gpu_region}): every model load will cross regions and pay egress."
  }
}
```

```
Warning: Check block assertion failed

  on main.tf line 39, in check "weights_next_to_gpus":
  39:     condition     = lower(var.region) == lower(var.gpu_region)
    ├────────────────
    │ var.gpu_region is "us-central1"
    │ var.region is "us-east1"

The models bucket (us-east1) isn't in the GPUs' region (us-central1): every
model load will cross regions and pay egress.
```

The plan still succeeds. Check blocks can also contain a **scoped data source** that's read only for the check, for example to verify that an endpoint answers, which makes them useful for continuous validation after apply.

## Running it all automatically

Locally, a [pre-commit](https://pre-commit.com/) hook runs the fast checks before every commit. The community [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform) hooks cover all of them:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.109.2
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
```

In CI, run the same commands on every pull request, and fail the job on any non-zero exit. [CI/CD](ci-cd.md) puts them in a GitHub Actions workflow, before the plan.

## Best practices

- **Run `fmt`, `validate`, `tflint`, and `terraform test` on every pull request.** None needs credentials.
- **Configure tflint with the google ruleset and the `recommended` preset**, and commit `.tflint.hcl`.
- **Write unit tests for every reusable module**, with `mock_provider` and `command = plan`. Test the rules you'd hate to see broken: naming, protection settings, environment differences, validations.
- **Use `expect_failures`** to prove that validations reject bad input.
- **Keep integration tests (`command = apply`) for nightly runs** in a separate project.
- **Use `check` blocks for warnings** and preconditions for hard rules.
- **Suppress lint findings in code, with a reason**, never by turning rules off globally.

## Clean up

Nothing to clean up: nothing in this chapter touches GCP.

---

[← Kubernetes & Helm Providers](../ai-infra/kubernetes-and-helm.md) · [↑ Contents](../../README.md) · [Security Scanning →](security-scanning.md)
