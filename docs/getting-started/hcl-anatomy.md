# Anatomy of HCL

> Blocks, arguments, and expressions, once and for all.

---

Terraform configurations are written in **HCL** (HashiCorp Configuration Language). It looks a bit like JSON, with less punctuation and with expressions built in. The good news: the whole language rests on **three building blocks**. Once you can name each part of a file, any Terraform code you open, from a one-file lab to a thousand-line production module, reads the same way.

## Before you start

The example for this chapter is the bucket from [Core Workflow](core-workflow.md), split into the conventional files, plus a second resource that refers to the first:

```bash
cd examples/getting-started/hcl-anatomy
terraform init
```

```
hcl-anatomy/
├── versions.tf    # terraform { } block: Terraform and provider versions
├── providers.tf   # provider "google" { }
├── variables.tf   # inputs
├── main.tf        # locals and resources
└── outputs.tf     # outputs
```

## The three building blocks

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
    block["🧱 Block<br/>type · labels · body"]
    arg["🔧 Argument<br/>name = value"]
    nested["📦 Nested block<br/>name { … }"]
    expr["🧮 Expression<br/>the value"]

    block -->|"body holds"| arg
    block -->|"body holds"| nested
    nested -->|"body holds"| arg
    arg -->|"right side is an"| expr

    classDef ctrl fill:#0F172A,stroke:#2563EB,stroke-width:2px,color:#FFFFFF
    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    classDef tgt fill:#0F172A,stroke:#16A34A,stroke-width:2px,color:#FFFFFF
    class block eng
    class arg,nested ctrl
    class expr tgt
```

Here they are in a real resource from `main.tf`:

```hcl
resource "google_storage_bucket" "notes" {   # block: type "resource", two labels
  name     = local.bucket_name               # argument: name = expression
  location = var.region                      # argument

  labels = local.common_labels               # argument whose value is a map

  versioning {                               # nested block: no "="
    enabled = true                           # argument inside the nested block
  }
}
```

### 1. Blocks

A **block** is a container with a **type**, zero or more **labels**, and a **body** in braces:

| Part | In the example | Meaning |
|---|---|---|
| Type | `resource` | what kind of block this is |
| Label 1 | `"google_storage_bucket"` | for a resource: which kind of thing to create |
| Label 2 | `"notes"` | for a resource: your local name for it |
| Body | `{ ... }` | the arguments and nested blocks |

The block type decides how many labels it takes. `resource` takes two, `variable` and `output` take one, and `terraform` and `locals` take none. You'll meet these block types in almost every configuration:

| Block | Labels | What it's for | Covered in |
|---|---|---|---|
| `terraform` | none | Terraform version, providers, backend | [Providers](../core-language/providers.md) |
| `provider` | provider name | Configure a provider (project, region) | [Providers](../core-language/providers.md) |
| `resource` | type, name | Something Terraform **creates and manages** | [Resources & Data Sources](../core-language/resources-and-data-sources.md) |
| `data` | type, name | Something Terraform only **reads** | [Resources & Data Sources](../core-language/resources-and-data-sources.md) |
| `variable` | name | An input | [Variables, Locals & Outputs](../core-language/variables-and-outputs.md) |
| `locals` | none | Named values computed inside the configuration | [Variables, Locals & Outputs](../core-language/variables-and-outputs.md) |
| `output` | name | A value exposed to the caller | [Variables, Locals & Outputs](../core-language/variables-and-outputs.md) |
| `module` | name | Call another directory of Terraform code | [Writing Modules](../modules/writing-modules.md) |

Labels are always plain quoted strings. You can't compute them with expressions.

### 2. Arguments

An **argument** assigns a value to a name: `name = value`. Within one block, each argument name can appear only once, and the provider's documentation lists which ones exist. For example, the [`google_storage_bucket` docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket) list `name`, `location`, `labels`, and the rest.

Lining up the `=` signs is just style. `terraform fmt` does it for you.

### 3. Nested blocks vs. map arguments: the `=` matters

This is the most common syntax mistake in Terraform. `labels` and `versioning` both look like "a name followed by braces", but they're different things:

```hcl
  labels = {          # ARGUMENT: its value is a map. Uses "=".
    team = "ml"
  }

  versioning {        # NESTED BLOCK: a structured part of the resource. No "=".
    enabled = true
  }
```

You can't tell which is which by guessing. The provider docs say which names are arguments and which are blocks. Get it wrong and `terraform validate` tells you exactly what happened:

```
Error: Unsupported argument

  on main.tf line 22, in resource "google_storage_bucket" "notes":
  22:   versioning = {

An argument named "versioning" is not expected here. Did you mean to define a
block of type "versioning"?
```

```
Error: Unsupported block type

  on main.tf line 19, in resource "google_storage_bucket" "notes":
  19:   labels {

Blocks of type "labels" are not expected here. Did you mean to define
argument "labels"? If so, use the equals sign to assign it a value.
```

The fix is in the message both times: add or remove the `=`.

## Expressions: the right-hand side

Everything to the right of `=` is an **expression**. It can be a literal like `"us-central1"`, or something Terraform evaluates. You'll see these kinds constantly:

| Kind | Example | Result |
|---|---|---|
| Literal | `"us-central1"`, `24`, `true`, `null` | itself |
| Reference | `var.region`, `local.bucket_name`, `google_storage_bucket.notes.name` | another value in the configuration |
| String template | `"${var.project_id}-models"` | `"tf-tutorial-3fa9c1-models"` |
| Function call | `upper(var.region)` | `"US-CENTRAL1"` |
| Operator | `length(local.common_labels) > 1` | `true` |
| Conditional | `var.env == "prod" ? 3 : 1` | one of two values |
| Collection | `["a", "b"]`, `{ team = "ml" }` | a list, a map |

Part 1 goes deep on [functions, `for` expressions, and conditionals](../core-language/expressions.md). For now, two forms matter most: references and templates.

### References: how one thing points at another

Every value in a configuration has an address you can refer to:

| To refer to | Write | Example |
|---|---|---|
| An input variable | `var.<name>` | `var.region` |
| A local value | `local.<name>` | `local.bucket_name` (block is `locals`, reference is `local`) |
| A resource attribute | `<type>.<name>.<attribute>` | `google_storage_bucket.notes.name` |
| A data source attribute | `data.<type>.<name>.<attribute>` | `data.google_project.this.number` |
| A module output | `module.<name>.<output>` | `module.network.subnet_id` |

### References create the dependency graph

In `main.tf`, the object refers to the bucket:

```hcl
resource "google_storage_bucket_object" "readme" {
  bucket = google_storage_bucket.notes.name   # ← reference
  name   = "README.txt"
  ...
}
```

That one reference does two jobs. It supplies the value, and it tells Terraform that **the object depends on the bucket**. Terraform builds a graph from every reference in the configuration:

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
    bucket["🪣 google_storage_bucket.notes"]
    obj["📄 google_storage_bucket_object.readme"]

    bucket ==>|"created before<br/>destroyed after"| obj

    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    classDef tgt fill:#0F172A,stroke:#16A34A,stroke-width:2px,color:#FFFFFF
    class bucket eng
    class obj tgt
```

- On `apply`, the bucket is created first, because the object needs its name.
- On `destroy`, the order reverses: the object goes first, then the bucket.
- Resources with no references between them are created **in parallel**.

You never write the order down. You can see the graph Terraform builds with `terraform graph`, which prints it in Graphviz format:

```
digraph G {
  rankdir = "RL";
  node [shape = rect, fontname = "sans-serif"];
  "google_storage_bucket.notes" [label="google_storage_bucket.notes"];
  "google_storage_bucket_object.readme" [label="google_storage_bucket_object.readme"];
  "google_storage_bucket_object.readme" -> "google_storage_bucket.notes";
}
```

This is why **order in the file doesn't matter**. You could put the object above the bucket and nothing would change. [Meta-Arguments](../core-language/meta-arguments.md) covers `depends_on`, for the rare dependency that a reference can't express.

### String templates and heredocs

`${ ... }` inside a quoted string inserts an expression's value:

```hcl
  bucket_name = "${var.project_id}-hcl-anatomy"
```

For multi-line text, use a **heredoc**. `<<-EOT` strips the common leading indentation, so the text can be indented with the rest of the code:

```hcl
  content = <<-EOT
    This bucket is managed by Terraform.
    Project: ${var.project_id}
    Region:  ${upper(var.region)}
  EOT
```

`EOT` is only a convention; any word works as long as the closing line matches. You'll use heredocs for startup scripts, small config files, and policy documents.

## Types

Every value has a type. You'll declare these on variables in [Variables, Locals & Outputs](../core-language/variables-and-outputs.md):

| Type | Example |
|---|---|
| `string` | `"us-central1"` |
| `number` | `24`, `0.5` |
| `bool` | `true`, `false` |
| `list(...)` | `["us-central1-a", "us-central1-b"]` (ordered) |
| `set(...)` | like a list, but unordered and without duplicates |
| `map(...)` | `{ team = "ml", env = "dev" }` (keys are strings, values share one type) |
| `object({...})` | `{ name = "l4-pool", gpus = 1 }` (fixed keys, each with its own type) |

Two details trip people up:

- **`null` means "not set".** Assigning `null` to an argument is the same as leaving it out, so the provider's default applies. This is very handy in modules.
- **Terraform converts types automatically when it safely can.** `5 + "3"` is `8`, because `"3"` converts to a number. When conversion fails, you get a clear error instead of a surprise: `tonumber("abc")` fails with `cannot convert "abc" to number`.

## Comments

```hcl
# The idiomatic single-line comment. Use this one.
// Also a single-line comment. Works, but less common.
/* A multi-line comment,
   handy for temporarily disabling a block. */
```

## Files and directories

- Terraform reads **every `.tf` file in the current directory** and merges them into one configuration. It doesn't look in subdirectories.
- **File names mean nothing to Terraform.** `versions.tf`, `variables.tf`, `main.tf`, and `outputs.tf` are a team convention that makes code easy to navigate. Everything would work the same in one file.
- A directory of `.tf` files is a **module**. The one you run `terraform` in is the **root module**. That's why you `cd` into an example before running it.

The conventional layout:

| File | Holds |
|---|---|
| `versions.tf` | the `terraform { }` block: `required_version`, `required_providers`, `backend` |
| `providers.tf` | `provider` blocks |
| `variables.tf` | `variable` blocks |
| `main.tf` | `locals`, `resource`, and `data` blocks. Split by topic (`network.tf`, `gke.tf`) as it grows |
| `outputs.tf` | `output` blocks |

## Try it: `terraform console`

`terraform console` is an interactive prompt where you can evaluate any expression against the current configuration. It's the fastest way to check a function or a reference before you use it. It doesn't change anything.

```bash
terraform console
```

```
> var.region
"us-central1"
> local.bucket_name
"tf-tutorial-3fa9c1-hcl-anatomy"
> upper(var.region)
"US-CENTRAL1"
> merge(local.common_labels, { team = "ml" })
{
  "managed-by" = "terraform"
  "team" = "ml"
  "tutorial" = "hcl-anatomy"
}
> google_storage_bucket.notes.name
(known after apply)
> exit
```

`google_storage_bucket.notes.name` shows `(known after apply)` until you've applied, because the console reads real values from state. Run `terraform apply` and ask again. You'll get the bucket name.

## Apply it

```bash
terraform plan
```

```
  # google_storage_bucket.notes will be created
  ...
  # google_storage_bucket_object.readme will be created
  + resource "google_storage_bucket_object" "readme" {
      + bucket          = "tf-tutorial-3fa9c1-hcl-anatomy"
      + content         = (sensitive value)
      ...
      + name            = "README.txt"
      ...
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bucket_name = "tf-tutorial-3fa9c1-hcl-anatomy"
  + readme_uri  = "gs://tf-tutorial-3fa9c1-hcl-anatomy/README.txt"
```

Notice two things:

- `bucket` is known at plan time, because it comes from `local.bucket_name`, which is computed from your variables, not from GCP. Only values that GCP decides show `(known after apply)`.
- `content = (sensitive value)`. The google provider marks object content as sensitive, so Terraform hides it in plans and logs. You'll see how and why in [Variables, Locals & Outputs](../core-language/variables-and-outputs.md).

Apply it, and read the object back:

```bash
terraform apply
gcloud storage cat "$(terraform output -raw readme_uri)"
```

```
This bucket is managed by Terraform.
Project: tf-tutorial-3fa9c1
Region:  US-CENTRAL1
```

The heredoc's indentation was stripped, and both `${ }` templates were filled in.

## Checkpoint

1. In `name = google_storage_bucket.models.name`, identify the argument, the resource reference, and the attribute being read.
2. If resource B refers to an attribute of resource A, do you normally need `depends_on`? Predict the apply order.
3. Misspell `var.region` as `var.regoin`, run `terraform validate`, and use the error to locate the broken reference. Then restore it.

<details>
<summary>Answer</summary>

1. `name` is the argument being assigned; `google_storage_bucket.models` is the resource address; the final `.name` reads its exported attribute.
2. No. The reference creates an implicit dependency, so Terraform orders A before the part of B that needs A's value. Reserve `depends_on` for dependencies that aren't expressed by data flow.
3. Validation reports a reference to an undeclared input variable. Terraform names are exact; changing it back to `var.region` restores the declared reference.

</details>

## Best practices

- **Run `terraform fmt` before every commit.** It ends all arguments about alignment and indentation.
- **Use the conventional file layout**, then split `main.tf` by topic once it grows past a screen or two.
- **Name resources for their role, not their type.** Write `google_storage_bucket.models`, not `google_storage_bucket.bucket`; the type is already in the address.
- **Use snake_case for local names** (`model_weights`, not `modelWeights` or `model-weights`).
- **Let references express order.** Reach for `depends_on` only when there's no attribute to refer to.
- **Check the provider docs for argument vs. block.** When unsure, `terraform validate` tells you in a second.

## Clean up

```bash
terraform destroy
```

Watch the order in the output: the object is destroyed before the bucket, which is the dependency graph running in reverse.

---

[← Core Workflow](core-workflow.md) · [↑ Contents](../../README.md) · [Providers & Version Pinning →](../core-language/providers.md)
