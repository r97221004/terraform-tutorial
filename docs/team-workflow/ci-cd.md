# CI/CD with GitHub Actions

> Workload Identity Federation (no JSON keys), plan on PR, apply on merge.

---

Running `terraform apply` from laptops doesn't scale: who applied what, from which branch, with which local changes? A pipeline fixes that. Every change goes through a pull request, where a preview plan is posted for review. After merge, CI creates a fresh deployment plan from the exact commit on `main`; a production reviewer inspects that plan and approves its apply. This chapter builds that pipeline with GitHub Actions, authenticated to GCP **without a single service account key**.

## Before you start

You need the state bucket from [Remote Backend](../state/remote-backend.md), and a GitHub repository for your Terraform code. The workflows expect the configuration in an `infra/` directory of that repository.

```bash
cd examples/team-workflow/ci-cd/wif
terraform init
```

The example has two parts:

| Path | What it is |
|---|---|
| [`wif/`](../../examples/team-workflow/ci-cd/wif/) | Terraform that lets one GitHub repository authenticate to GCP: a Workload Identity pool, separate plan/apply providers, and two service accounts |
| [`workflows/`](../../examples/team-workflow/ci-cd/workflows/) | two workflow files to copy into that repository's `.github/workflows/` |

## Keyless authentication

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
    job["🤖 GitHub Actions job<br/>id-token: write"]
    gh(["🐙 GitHub OIDC<br/>token.actions.githubusercontent.com"])
    sts["🔐 GCP STS<br/>pool github · plan/apply providers<br/>repo ID + workflow conditions"]
    sa["👤 terraform-plan or<br/>terraform-apply SA"]
    gcp["☁️ GCP APIs + state bucket"]

    gh -->|"1 · signed token<br/>sub, repository, ref"| job
    job ==>|"2 · exchange"| sts
    sts ==>|"3 · impersonate"| sa
    sa ==>|"4 · 1-hour credentials"| gcp

    classDef ctrl fill:#0F172A,stroke:#2563EB,stroke-width:2px,color:#FFFFFF
    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    classDef tgt fill:#0F172A,stroke:#16A34A,stroke-width:2px,color:#FFFFFF
    class job,gh ctrl
    class sts,sa eng
    class gcp tgt
```

GitHub issues every workflow job an **OIDC token**: a signed statement of which repository, branch, and environment the job is running for. GCP's **Workload Identity Federation** trusts GitHub's signature, checks the token against your rules, and lets the job impersonate a service account for an hour. It's the CI equivalent of [Workload Identity for GKE](../ai-infra/workload-identity.md): identity comes from where the code runs, not from a secret someone copied.

### The pool and providers

From [`wif/main.tf`](../../examples/team-workflow/ci-cd/wif/main.tf):

```hcl
resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project_service.enabled["sts.googleapis.com"].project
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "plan" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-plan"
  display_name                       = "GitHub Terraform plan"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"          = "assertion.repository_id + ':' + assertion.run_id"
    "attribute.access"        = "'plan'"
    "attribute.repository_id" = "assertion.repository_id"
    "attribute.workflow_ref"  = "assertion.workflow_ref"
  }

  attribute_condition = <<-EOT
    assertion.repository_id == '${var.github_repository_id}' &&
    (assertion.workflow_ref.startsWith('${var.github_repository}/.github/workflows/terraform.yml@') ||
     assertion.workflow_ref.startsWith('${var.github_repository}/.github/workflows/drift.yml@')) &&
    (assertion.event_name == 'pull_request' ||
     (assertion.event_name == 'push' && assertion.ref == 'refs/heads/main') ||
     assertion.event_name == 'schedule' ||
     assertion.event_name == 'workflow_dispatch')
  EOT
}

resource "google_iam_workload_identity_pool_provider" "apply" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-apply"
  display_name                       = "GitHub Terraform apply"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"          = "assertion.repository_id + ':' + assertion.run_id"
    "attribute.access"        = "'apply'"
    "attribute.repository_id" = "assertion.repository_id"
    "attribute.workflow_ref"  = "assertion.workflow_ref"
  }

  attribute_condition = <<-EOT
    assertion.repository_id == '${var.github_repository_id}' &&
    assertion.workflow_ref == '${var.github_repository}/.github/workflows/terraform.yml@refs/heads/main' &&
    assertion.event_name == 'push' &&
    assertion.ref == 'refs/heads/main' &&
    assertion.environment == 'production'
  EOT
}
```

**The conditions are the trust boundary.** Both providers require the repository's [immutable numeric ID](https://github.com/google-github-actions/auth/blob/main/docs/SECURITY_CONSIDERATIONS.md), rather than only its reusable `OWNER/REPO` name. The plan provider also limits tokens to the two copied workflow paths and expected events. The apply provider is narrower still: only `terraform.yml` from `main`, on a `push`, after the protected `production` environment has been approved. The workflow paths still contain `OWNER/REPO`, so re-apply this configuration with the new name if you rename the repository.

[GitHub's default OIDC `sub`](https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims) has a legacy and an immutable format. The configuration does not depend on either: it builds the required audit subject from `repository_id` and `run_id`, then authorizes with individual repository, workflow, event, ref, and environment claims.

### Two identities: plan and apply

```hcl
resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool_path}/attribute.access/plan"
}

resource "google_service_account_iam_member" "apply_wif" {
  service_account_id = google_service_account.apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool_path}/attribute.access/apply"
}
```

| Service account | Accepted token | Project and state roles |
|---|---|---|
| `terraform-plan` | the named plan/drift workflows in this repository, for the listed events | project `roles/viewer`; bucket `storage.objectViewer` |
| `terraform-apply` | `terraform.yml` from `main`, on push, in the approved `production` environment | `roles/editor`, `projectIamAdmin`; bucket `storage.objectUser` |

The plan identity can refresh real resources and read state, but it cannot write resources, state, or lock objects. Plan and drift commands therefore use `-lock=false`. Apply has the write-capable identity, takes the normal state lock, and is available only after production approval.

> ⚠️ **A plan still reads sensitive state and runs code from the proposed configuration.** By default, pull requests from forks get no OIDC token, so the real exposure is branches in the same repository: limit who can push branches, review dependency and workflow changes before trusting a plan, and do not store secrets in Terraform state. Read-only state prevents corruption; it does not make state public or harmless.

`roles/editor` is a pragmatic start for the apply identity; it's a [basic role](../gcp-foundations/iam.md#iam-in-one-picture). Once your configurations settle, replace it with the predefined roles they actually need (the [IAM recommender](https://cloud.google.com/policy-intelligence/docs/role-recommendations-overview) will tell you which ones are used).

### Apply it

```bash
GITHUB_REPOSITORY=OWNER/REPO
GITHUB_REPOSITORY_ID=$(gh api "repos/$GITHUB_REPOSITORY" --jq .id)
terraform apply \
  -var github_repository="$GITHUB_REPOSITORY" \
  -var github_repository_id="$GITHUB_REPOSITORY_ID" \
  -var state_bucket="$TF_VAR_project_id-tfstate"
terraform output
```

```
apply_service_account = "terraform-apply@tf-tutorial-3fa9c1.iam.gserviceaccount.com"
apply_workload_identity_provider = "projects/123456789012/locations/global/workloadIdentityPools/github/providers/github-apply"
plan_service_account = "terraform-plan@tf-tutorial-3fa9c1.iam.gserviceaccount.com"
plan_workload_identity_provider = "projects/123456789012/locations/global/workloadIdentityPools/github/providers/github-plan"
```

Then, in the GitHub repository:

1. **Settings → Secrets and variables → Actions → Variables**: add `GCP_PROJECT_ID`, `PLAN_WIF_PROVIDER`, `APPLY_WIF_PROVIDER`, `PLAN_SA`, `APPLY_SA` (the four outputs above), and `TF_STATE_BUCKET`. They're variables, not secrets: none of them grants anything by itself.
2. **Settings → Environments**: create `production`, add **required reviewers**, and limit it to the `main` branch.
3. Copy `workflows/terraform.yml` and `workflows/drift.yml` to `.github/workflows/`.

There's no JSON key anywhere: not in GitHub secrets, not on a laptop.

## The pipeline

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
    pr(["✏️ pull request"])
    prchecks["🧪 PR checks"]
    preview["📋 preview plan"]
    comment["💬 preview posted<br/>on the PR"]
    merge(["🔀 merge to main"])
    deploychecks["🧪 deployment checks"]
    deployplan["📋 fresh plan<br/>from main"]
    approve{"👀 review plan +<br/>production approval"}
    apply["🚀 apply saved plan<br/>terraform-apply SA"]

    pr --> prchecks --> preview --> comment --> merge
    merge --> deploychecks --> deployplan --> approve
    approve -->|"approved"| apply

    classDef ctrl fill:#0F172A,stroke:#2563EB,stroke-width:2px,color:#FFFFFF
    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    classDef tgt fill:#0F172A,stroke:#16A34A,stroke-width:2px,color:#FFFFFF
    class pr,merge ctrl
    class prchecks,preview,deploychecks,deployplan,approve eng
    class comment,apply tgt
```

[`workflows/terraform.yml`](../../examples/team-workflow/ci-cd/workflows/terraform.yml) has three jobs.

### 1. Checks, without credentials

```yaml
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: hashicorp/setup-terraform@v4
        with:
          terraform_version: "~1.16"
      - uses: terraform-linters/setup-tflint@v6
      - run: terraform fmt -check -recursive
      - run: terraform init -backend=false
      - run: terraform validate
      - run: tflint --init && tflint
      - uses: aquasecurity/trivy-action@v0.36.0
        with:
          scan-type: config
          scan-ref: ${{ env.TF_DIR }}
          severity: HIGH,CRITICAL
          exit-code: "1"
```

Everything from [Testing & Code Quality](testing-and-quality.md) and [Security Scanning](security-scanning.md), with `init -backend=false` so no credentials are needed. If you have module tests, add `terraform test` here.

### 2. Plan: preview on PR, deployment artifact on main

```yaml
  plan:
    needs: checks
    permissions:
      contents: read
      id-token: write       # lets the job request a GitHub OIDC token
      pull-requests: write  # lets the job comment the plan on the PR
    steps:
      - uses: actions/checkout@v7

      # Exchange GitHub's OIDC token for short-lived Google credentials. No keys.
      - uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: ${{ vars.PLAN_WIF_PROVIDER }}
          service_account: ${{ vars.PLAN_SA }}
      ...
      - run: >-
          terraform init
          -backend-config="bucket=${{ vars.TF_STATE_BUCKET }}"
          -backend-config="prefix=${{ env.TF_DIR }}"

      - run: terraform plan -lock=false -out=tfplan
      - run: terraform show -no-color tfplan > plan.txt

      - name: Upload deployment plan
        if: github.event_name == 'push'
        uses: actions/upload-artifact@v7
        with:
          name: tfplan
          path: ${{ env.TF_DIR }}/tfplan
          retention-days: 1

      - name: Comment the plan on the pull request
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v9
        ...

      - name: Add deployment plan to the run summary
        if: github.event_name == 'push'
        run: |
          # Append plan.txt to $GITHUB_STEP_SUMMARY for the approver.
          ...
```

- **`id-token: write`** is what allows the job to request the OIDC token. Without it, `google-github-actions/auth` fails.
- **`-lock=false`** is deliberate: the plan identity has `storage.objectViewer`, so it can read state but cannot create the lock or update state. The later apply takes the lock and rejects the saved plan if state changed meanwhile.
- On a **pull request**, the plan is posted as a comment so reviewers can catch replacements and unexpected changes next to the code. It is a preview, not the file that will eventually be applied.
- After merge, the `push` event starts a **new workflow run** against the exact commit on `main`. That run creates a fresh plan, puts its readable form in the run summary, and uploads the binary plan for its own apply job.
- The PR and post-merge plans should normally agree, but they can differ if state, provider data, or `main` changed between runs. The production reviewer must inspect the post-merge plan rather than relying only on the PR comment.
- Saved plans can contain sensitive values. The PR run does not upload one; the deployment artifact is retained for one day only. Keep repository and Actions access appropriately restricted.

### 3. Apply the post-merge plan, after approval

```yaml
  apply:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: plan
    environment: production   # waits for a required reviewer
    concurrency:
      group: terraform-apply  # never two applies at once
      cancel-in-progress: false
    ...
    steps:
      ...
      - uses: google-github-actions/auth@v3
        with:
          workload_identity_provider: ${{ vars.APPLY_WIF_PROVIDER }}
          service_account: ${{ vars.APPLY_SA }}
      ...
      - uses: actions/download-artifact@v8
        with:
          name: tfplan
          path: ${{ env.TF_DIR }}

      # Apply the post-merge plan from this same workflow run. If state changed
      # since it was created, Terraform refuses and the run must be repeated.
      - run: terraform apply -lock-timeout=5m tfplan
```

- **`environment: production`** pauses the job until a required reviewer approves it in the GitHub UI. Before approving, open the run summary and inspect the deployment plan generated from `main`. The apply provider checks the environment claim directly; it does not depend on GitHub's legacy or immutable `sub` format.
- **The apply uses the saved plan from the plan job of the same post-merge run.** That guarantees the approved deployment run applies its saved artifact rather than calculating an unreviewed plan during `apply` ([Core Workflow](../getting-started/core-workflow.md#7-saved-plans-apply-exactly-what-you-reviewed)). If state changes in between, Terraform refuses the stale plan.
- **`concurrency`** queues applies one after another; with the state lock as a second safety net.

The workflow files pass [actionlint](https://github.com/rhysd/actionlint), the linter for GitHub Actions; run it on your copies after editing them.

## Drift detection, every night

[State & Drift](../state/state-basics.md#detecting-drift-automatically) introduced `plan -detailed-exitcode`. [`workflows/drift.yml`](../../examples/team-workflow/ci-cd/workflows/drift.yml) runs it on a schedule, with the read-only plan identity, and opens an issue when reality no longer matches the code:

```yaml
on:
  schedule:
    - cron: "0 6 * * *"  # 06:00 UTC daily
  workflow_dispatch:
...
      # Exit code 0 = no changes, 1 = error, 2 = changes (drift).
      - id: plan
        run: |
          set +e
          terraform plan -detailed-exitcode -lock=false -no-color > plan.txt
          code=$?
          echo "exitcode=$code" >> "$GITHUB_OUTPUT"
          if [ "$code" -eq 1 ]; then cat plan.txt; exit 1; fi

      - name: Open an issue on drift
        if: steps.plan.outputs.exitcode == '2'
        uses: actions/github-script@v9
        ...
```

Exit code 2 means either drift or merged code that was never applied. Both deserve a look the next morning.

## Several configurations

The workflow targets one directory, `infra/`. For several configurations (environments and components, as in [Environments](../modules/environments.md)), turn `TF_DIR` into a **matrix** of directories, each with its own state prefix, and give each environment its own GitHub environment, approvers, and apply identity. Production and development then have separate approvals and separate credentials.

## Checkpoint

1. Is the PR-commented plan the binary plan applied after merge in this workflow? Describe the two runs.
2. Why do the providers check the immutable repository ID and individual claims instead of matching the complete OIDC `sub`?
3. Why does plan use `storage.objectViewer` with `-lock=false`, while apply uses `storage.objectUser`?

<details>
<summary>Answer</summary>

1. No. The PR run posts a preview. After merge, a new `push` run checks out the exact `main` commit, creates a fresh deployment plan, pauses for approval, and applies the saved artifact from that same run.
2. GitHub repositories share one issuer, while the default `sub` has legacy and immutable formats. Repository ID is unique and non-reusable; workflow, event, ref, and environment claims express the actual authorization rules without parsing `sub`.
3. Plans need to read state and refresh resources, but they do not need to mutate state. Disabling the lock makes bucket read-only sufficient. Apply must create the lock and update state, so only its protected identity gets object-write permissions.

</details>

## Best practices

- **No service account keys in CI.** Use Workload Identity Federation with `google-github-actions/auth`.
- **Use immutable repository IDs and explicit workflow/event conditions**, rather than authorizing the complete `sub` string or only a reusable repository name.
- **Separate plan and apply identities**: read-only for plans, write access only from a protected environment.
- **Run read-only plans with `-lock=false`**, so the plan identity needs only `storage.objectViewer`; let apply own locking and state writes.
- **Post a preview plan on every pull request** and review it, not just the code.
- **Plan again from the merged commit**, show that deployment plan to the production approver, and apply its saved artifact from the same run.
- **Treat saved plans as sensitive**, restrict artifact access, and keep their retention short.
- **Serialize applies** with `concurrency`, and wait for locks with `-lock-timeout`.
- **Run fmt, validate, tflint, tests, and a security scan before every plan.**
- **Check for drift on a schedule**, with the read-only identity.
- **Pin action versions.** Major tags (`@v3`) are a minimum; pinning to a full commit SHA protects against a compromised tag.

## Clean up

```bash
cd examples/team-workflow/ci-cd/wif
GITHUB_REPOSITORY=OWNER/REPO
GITHUB_REPOSITORY_ID=$(gh api "repos/$GITHUB_REPOSITORY" --jq .id)
terraform destroy \
  -var github_repository="$GITHUB_REPOSITORY" \
  -var github_repository_id="$GITHUB_REPOSITORY_ID" \
  -var state_bucket="$TF_VAR_project_id-tfstate"
```

A deleted Workload Identity pool is kept for 30 days and its ID can't be reused during that time; pick a new `workload_identity_pool_id` if you recreate it sooner.

---

[← Security Scanning](security-scanning.md) · [↑ Contents](../../README.md) · [LLM Inference Platform on GKE →](../capstone/llm-platform.md)
