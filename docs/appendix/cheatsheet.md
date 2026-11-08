# Terraform Cheat Sheet

> One-page reference.

---

The commands, syntax, and patterns used throughout this guide, with links to where each is explained.

## The workflow

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
    init["init"] --> fmt["fmt"] --> validate["validate"] --> plan["plan -out=tfplan"] --> apply["apply tfplan"]
    apply -.->|"when done"| destroy["destroy"]

    classDef ctrl fill:#0F172A,stroke:#2563EB,stroke-width:2px,color:#FFFFFF
    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    class init,fmt,validate ctrl
    class plan,apply,destroy eng
```

## Commands

### Everyday

| Command | Does |
|---|---|
| `terraform init` | install providers and modules, configure the backend |
| `terraform init -upgrade` | pick the newest provider/module versions allowed by the constraints |
| `terraform init -backend-config=backend.hcl` | partial backend configuration ([Remote Backend](../state/remote-backend.md)) |
| `terraform init -migrate-state` / `-reconfigure` | after a backend change: copy state / start fresh |
| `terraform fmt -recursive` (`-check` in CI) | format all files |
| `terraform validate` | check syntax, types, references |
| `terraform plan` | show what would change |
| `terraform plan -out=tfplan` → `terraform apply tfplan` | apply exactly what you reviewed ([Core Workflow](../getting-started/core-workflow.md)) |
| `terraform apply` / `terraform destroy` | create or update / delete everything |
| `terraform output [-raw NAME \| -json]` | read outputs from state |
| `terraform console` | evaluate expressions interactively |
| `terraform test` | run `tests/*.tftest.hcl` ([Testing](../team-workflow/testing-and-quality.md)) |

### Useful flags

| Flag | Use |
|---|---|
| `-var 'name=value'`, `-var-file=prod.tfvars` | set variables ([precedence](../core-language/variables-and-outputs.md#setting-values-and-which-one-wins)) |
| `-refresh-only` | show or record drift without changing anything ([State & Drift](../state/state-basics.md)) |
| `-detailed-exitcode` | `plan` exits 0 (no changes), 1 (error), 2 (changes) |
| `-lock-timeout=5m` | wait for another run's state lock |
| `-target=ADDRESS` | limit to one resource; emergencies only |
| `-generate-config-out=FILE` | write config for `import` blocks ([Refactoring](../state/refactoring.md)) |
| `-chdir=DIR` | run in another directory |
| `-input=false`, `TF_IN_AUTOMATION=true` | for CI |

### State

| Command | Does |
|---|---|
| `terraform state list` | every address in state |
| `terraform state show ADDRESS` | one resource's attributes |
| `terraform show -json [tfplan]` | state or a plan as JSON, for `jq` and scanners |
| `terraform state pull` | raw state, even when remote |
| `terraform providers` | which modules require which provider versions |
| `terraform force-unlock ID` | remove a stale lock, when sure nothing is running |
| `terraform workspace list/new/select` | CLI workspaces ([Environments](../modules/environments.md)) |

Prefer blocks over `terraform state mv`, `state rm`, and `terraform import`: `moved`, `removed`, and `import` go through a plan.

## Syntax

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 8.0" }
  }
  backend "gcs" {} # settings from backend.hcl
}

provider "google" {
  project        = var.project_id
  region         = var.region
  default_labels = { managed-by = "terraform" }
}

variable "environment" {
  type        = string
  description = "dev or prod."
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

locals {
  name = "${var.project_id}-${var.environment}"
}

data "google_project" "this" {} # read something that exists

resource "google_storage_bucket" "models" { # manage something
  name     = local.name
  location = var.region
}

output "bucket_url" {
  description = "gs:// URL of the bucket."
  value       = google_storage_bucket.models.url
}

module "network" {
  source = "./modules/vpc" # or registry: ns/name/provider + version
  name   = "ml-vpc"
}
```

### Expressions

| Expression | Example |
|---|---|
| Reference | `var.x`, `local.x`, `TYPE.NAME.ATTR`, `data.TYPE.NAME.ATTR`, `module.NAME.OUTPUT` |
| Template | `"${var.project_id}-models"` |
| Conditional | `var.env == "prod" ? 3 : 1` |
| `for` → list | `[for m in var.models : m.name if m.enabled]` |
| `for` → map | `{ for m in var.models : m.name => m.gpus }` |
| Splat | `var.models[*].name` |
| Heredoc | `<<-EOT ... EOT` |

Functions used most: `merge`, `lookup`, `contains`, `length`, `keys`, `values`, `toset`, `jsonencode`, `yamlencode`, `templatefile`, `cidrsubnet`, `try`, `can`, `coalesce`, `one` ([Expressions & Functions](../core-language/expressions.md)).

### Meta-arguments

| Meta-argument | Example |
|---|---|
| `count` | `count = var.enabled ? 1 : 0` → `one(TYPE.NAME[*].ATTR)` |
| `for_each` | `for_each = var.datasets` → `each.key`, `each.value`, `TYPE.NAME["key"]` |
| `depends_on` | `depends_on = [google_project_service.enabled]` |
| `provider` | `provider = google.dr` |
| `lifecycle` | `prevent_destroy`, `ignore_changes`, `create_before_destroy`, `replace_triggered_by`, `precondition`, `postcondition` |

### Refactoring blocks

```hcl
moved {
  from = google_storage_bucket.a
  to   = google_storage_bucket.b
}

import {
  to = google_storage_bucket.legacy
  id = "bucket-name"
}

removed {
  from = google_storage_bucket.old
  lifecycle {
    destroy = false
  }
}
```

## Plan symbols

| Symbol | Meaning |
|---|---|
| `+` | create |
| `~` | update in place |
| `-/+` | destroy, then create a replacement (look for `# forces replacement`) |
| `+/-` | create the replacement first (`create_before_destroy`) |
| `-` | destroy |
| `<=` | read a data source during apply |

## GCP patterns from this guide

| Pattern | Chapter |
|---|---|
| `google_project_service` with `for_each` and `disable_on_destroy = false` | [Projects & APIs](../gcp-foundations/projects-and-apis.md) |
| `_iam_member` (never `_iam_policy`) at the narrowest scope | [IAM](../gcp-foundations/iam.md) |
| One service account per workload; `.member` for principals | [IAM](../gcp-foundations/iam.md) |
| Custom VPC, `/14` Pod range, Private Google Access, Cloud NAT | [Networking](../gcp-services/networking.md) |
| Bucket: uniform access, public access prevention, lifecycle rules by age and class | [Cloud Storage](../gcp-services/cloud-storage.md) |
| VM: own service account with `cloud-platform` scope, `allow_stopping_for_update`, IAP SSH by tag | [Compute Engine](../gcp-services/compute-engine.md) |
| Cloud Run: own service account, `max_instance_count`, `cpu_idle = true` with `resources`, invoker on the service | [Cloud Run](../gcp-services/cloud-run.md) |
| Secret container in Terraform, value via `gcloud` or `*_wo` | [Secret Manager](../gcp-foundations/secrets.md) |
| State in GCS: versioned, `prevent_destroy`, one prefix per root | [Remote Backend](../state/remote-backend.md) |
| Separate node pools, private nodes, DNS endpoint | [GKE Cluster](../ai-infra/gke-cluster.md) |
| GPU pool: Spot, `total_min_node_count = 0`, `location_policy = "ANY"` | [GPU Node Pools](../ai-infra/gpu-node-pools.md) |
| `principal://…/subject/ns/NS/sa/KSA` for Workload Identity | [Workload Identity](../ai-infra/workload-identity.md) |
| Workloads in a separate configuration; ephemeral `google_client_config` | [Kubernetes & Helm](../ai-infra/kubernetes-and-helm.md) |
| WIF for CI; plan and apply identities; apply the saved plan | [CI/CD](../team-workflow/ci-cd.md) |

## Environment variables

| Variable | Effect |
|---|---|
| `TF_VAR_name` | sets variable `name` |
| `TF_LOG=DEBUG` | provider and core debug logs (may contain tokens) |
| `TF_IN_AUTOMATION=true` | quieter output for CI |
| `TF_CLI_ARGS_plan="-lock-timeout=5m"` | extra arguments for one command |
| `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT` | run as a service account via impersonation |

---

[← Cleanup](../capstone/cleanup.md) · [↑ Contents](../../README.md) · [Troubleshooting →](troubleshooting.md)
