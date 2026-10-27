# Core Workflow

> init → plan → apply → destroy, starting from a single file on your own disk.

---

This chapter builds one tiny configuration step by step, and adds one new idea at a time. You'll start with a single resource that writes a text file, then change it, add a second resource, break it by hand, and finally destroy everything. Nothing here touches the cloud, and nothing costs money.

## Before you start

All you need is Terraform from [Setup](setup.md#install-terraform):

```bash
terraform version   # v1.11 or newer
```

Make an empty directory to work in. You'll type the configuration yourself; it's only a few lines:

```bash
mkdir -p ~/terraform-first && cd ~/terraform-first
```

The finished version is in [`examples/getting-started/core-workflow/`](../../examples/getting-started/core-workflow/) if you want to compare at the end.

## The loop you'll use for everything

Four commands cover almost all day-to-day Terraform work. You'll repeat the middle two constantly:

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
    write(["✏️ write / edit<br/>.tf files"])
    init["📥 terraform init<br/>download providers"]
    plan["🔍 terraform plan<br/>preview the diff"]
    apply["🚀 terraform apply<br/>make it real"]
    destroy["🧹 terraform destroy<br/>remove everything"]

    write --> init
    init --> plan
    plan --> apply
    apply -->|"next change"| write
    write -. "already initialized" .-> plan
    apply -. "done with it" .-> destroy

    classDef ctrl fill:#0F172A,stroke:#2563EB,stroke-width:2px,color:#FFFFFF
    classDef eng fill:#7B42BC,stroke:#4C1D95,stroke-width:3px,color:#FFFFFF
    classDef tgt fill:#0F172A,stroke:#16A34A,stroke-width:2px,color:#FFFFFF
    class write ctrl
    class plan,apply eng
    class init,destroy tgt
```

You only re-run `init` when you add a provider or module, or change the backend. Every other change goes straight from editing to `plan`.

## Your first configuration

Create a file named `main.tf` with this content:

```hcl
resource "local_file" "greeting" {
  filename = "hello.txt"
  content  = "Hello, Terraform!"
}
```

That's a complete Terraform configuration. It says: *"there should be a file called `hello.txt` containing `Hello, Terraform!`"*. Each part has a name:

| Part | Here | Meaning |
|---|---|---|
| Block type | `resource` | something Terraform creates and manages |
| Resource type | `local_file` | what kind of thing. The part before `_`, `local`, is the **provider** that knows how to make it |
| Local name | `greeting` | your name for it, used to refer to it elsewhere |
| Arguments | `filename`, `content` | the settings you want it to have |

Together, the resource type and local name form the resource's **address**: `local_file.greeting`. You'll see addresses in every plan. The next chapter, [Anatomy of HCL](hcl-anatomy.md), takes the syntax apart properly; for now, this is all you need.

A file on your disk stands in for a cloud resource here. The workflow is exactly the one you'll use on GCP from Part 2 on; where local resources behave differently, the chapter says so.

## 1. `terraform init`: prepare the directory

```bash
terraform init
```

```
Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/local...
- Installing hashicorp/local v2.9.1...
- Installed hashicorp/local v2.9.1 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!
```

Terraform saw `local_file`, worked out that it needs the `local` provider, and downloaded it. `init` doesn't create anything; it only prepares the directory:

- **Downloads providers** into `.terraform/`. Think of it as a cache: never commit it, and it's safe to delete.
- **Writes `.terraform.lock.hcl`**, which records the exact provider version it chose. **Commit this file**, so everyone runs the same version. [Providers & Version Pinning](../core-language/providers.md) covers it, and the version settings real configurations add.
- **Sets up the backend**, the place state is stored. With none configured, that's a local file. You'll move it to GCS in [Remote Backend on GCS](../state/remote-backend.md).

`init` is safe to run any number of times.

## 2. `fmt` and `validate`: cheap checks first

Two quick commands catch mistakes before anything is created:

```bash
terraform fmt        # rewrites files into the standard style; prints the files it changed
terraform validate   # checks syntax and references, without creating anything
```

```
Success! The configuration is valid.
```

`validate` catches typos, like a misspelled argument name. It can't catch problems only the real system knows about, such as a directory you can't write to, or, on a cloud, a bucket name someone else already took. `plan` and `apply` find those.

## 3. `terraform plan`: preview the change

```bash
terraform plan
```

```
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # local_file.greeting will be created
  + resource "local_file" "greeting" {
      + content              = "Hello, Terraform!"
      + content_base64sha256 = (known after apply)
      + content_base64sha512 = (known after apply)
      + content_md5          = (known after apply)
      + content_sha1         = (known after apply)
      + content_sha256       = (known after apply)
      + content_sha512       = (known after apply)
      + directory_permission = "0777"
      + file_permission      = "0777"
      + filename             = "hello.txt"
      + id                   = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

Read it from the top:

- **`# local_file.greeting will be created`**: the address, and what will happen to it.
- **`+`** in front of each line: the value it will be created with. You wrote two of them. `file_permission` and `directory_permission` are **defaults** the provider fills in.
- **`(known after apply)`**: values that only exist once the file does, such as its checksums and `id`. On a cloud, IDs and IP addresses look the same.
- **`Plan: 1 to add, 0 to change, 0 to destroy.`**: the summary line. Read it every time.

`plan` only looks; it changes nothing. Run it as often as you like.

### The four symbols

Every plan uses the same notation. Learn these and you can read any plan:

| Symbol | Meaning | Risk |
|---|---|---|
| `+` | create | Low: something new appears |
| `~` | update in place | Usually low: the resource keeps its identity |
| `-` | destroy | **High**: the resource and its data are gone |
| `-/+` | destroy, then create a replacement | **High**: same address, but a brand-new resource. Data doesn't carry over |

You'll see `+` and `-/+` in this chapter. `~` needs a setting that can change on a live object, like a bucket's labels; you'll meet it on GCP in Part 2.

## 4. `terraform apply`: make it real

```bash
terraform apply
```

`apply` shows the plan again and asks for confirmation:

```
Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

local_file.greeting: Creating...
local_file.greeting: Creation complete after 0s [id=42086c02e03bf671ddf621ed9922f52f2c7a605c]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Only the exact word `yes` approves the plan. Anything else cancels it.

Check that it's real, with a tool other than Terraform:

```bash
cat hello.txt
```

```
Hello, Terraform!
```

(Your shell prompt may appear right after the text, on the same line. The content has no line break at the end, because you didn't write one.)

Now look at what else appeared in the directory:

```bash
ls -a
# .  ..  .terraform  .terraform.lock.hcl  hello.txt  main.tf  terraform.tfstate
```

`terraform.tfstate` is new. It's Terraform's record that the address `local_file.greeting` is the real file `hello.txt`. `terraform show` prints what it remembers:

```bash
terraform show
```

```
# local_file.greeting:
resource "local_file" "greeting" {
    content              = "Hello, Terraform!"
    ...
    filename             = "hello.txt"
    id                   = "42086c02e03bf671ddf621ed9922f52f2c7a605c"
}
```

**Never edit `terraform.tfstate` by hand, and never commit it.** It can contain secrets, and it's the only link between your code and what exists. [State & Drift](../state/state-basics.md) covers it properly.

Run `plan` again:

```bash
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

The code and the real world agree, so there's nothing to do. That's what **declarative** means: you describe the result, and applying the same configuration twice is always safe.

## 5. Change something

### Change an argument

In `main.tf`, change the content to `"Hello again, Terraform!"` and plan:

```bash
terraform plan
```

```
  # local_file.greeting must be replaced
-/+ resource "local_file" "greeting" {
      ~ content              = "Hello, Terraform!" -> "Hello again, Terraform!" # forces replacement
      ...
      ~ id                   = "42086c02e03bf671ddf621ed9922f52f2c7a605c" -> (known after apply)
        # (3 unchanged attributes hidden)
    }

Plan: 1 to add, 0 to change, 1 to destroy.
```

- **`~`** on a line shows the old value and the new one: `"Hello, Terraform!" -> "Hello again, Terraform!"`.
- **`-/+`** and **`must be replaced`**: Terraform will delete the file and create a new one. The `local` provider can't edit a file in place, so any change replaces it.
- **`# forces replacement`** marks the argument responsible.

For a text file, that's harmless. Apply it:

```bash
terraform apply
```

For a bucket holding model weights, the same `-/+` would mean deleting the bucket and every object in it. That's why you read every plan before you type `yes`: a one-word edit can mean "delete my data", and the plan is the only place that tells you.

### Add a second resource

Real configurations have many resources that refer to each other. Replace `main.tf` with:

```hcl
resource "random_pet" "name" {}

resource "local_file" "greeting" {
  filename = "hello.txt"
  content  = "Hello, ${random_pet.name.id}!"
}

output "pet_name" {
  value = random_pet.name.id
}
```

Three new things:

- **`random_pet`** generates a random name like `definite-koi`. Its block is empty because every argument has a default.
- **`${random_pet.name.id}`** inserts the generated name into the text. That's a **reference**: `random_pet.name` is the address, `.id` the value you want.
- **`output`** prints a value after `apply`.

Run `plan`, and Terraform stops you:

```
Error: Inconsistent dependency lock file

The following dependency selections recorded in the lock file are
inconsistent with the current configuration:
  - provider registry.terraform.io/hashicorp/random: required by this configuration but no version is selected
```

`random_pet` comes from a provider you haven't installed yet, `random`. This is the "you added a provider" case from the loop diagram. (The message suggests `init -upgrade`; plain `init` is enough here, because nothing that's already locked needs to change.)

```bash
terraform init
terraform plan
```

```
  # local_file.greeting must be replaced
-/+ resource "local_file" "greeting" {
      ~ content              = "Hello again, Terraform!" -> (known after apply) # forces replacement
      ...
    }

  # random_pet.name will be created
  + resource "random_pet" "name" {
      + id        = (known after apply)
      + length    = 2
      + separator = "-"
    }

Plan: 2 to add, 0 to change, 1 to destroy.

Changes to Outputs:
  + pet_name = (known after apply)
```

The new content is `(known after apply)`, because the pet name doesn't exist yet. Apply it and watch the order:

```bash
terraform apply
```

```
local_file.greeting: Destroying... [id=c3770660d07505e77d981f169412837fb9a552a5]
local_file.greeting: Destruction complete after 0s
random_pet.name: Creating...
random_pet.name: Creation complete after 0s [id=definite-koi]
local_file.greeting: Creating...
local_file.greeting: Creation complete after 0s [id=547b3ab13d6a0d2250c6bf25d4e4901dee4982b6]

Apply complete! Resources: 2 added, 0 changed, 1 destroyed.

Outputs:

pet_name = "definite-koi"
```

The name was created before the new file, because the file's content needs it. You never wrote that order down; Terraform worked it out from the reference. Your pet name will be different; that's the point of `random_pet`.

```bash
cat hello.txt                   # Hello, definite-koi!
terraform output -raw pet_name  # definite-koi, without quotes, for use in scripts
```

## 6. Drift: someone changes it by hand

Terraform only knows about changes made through Terraform. Simulate a teammate "cleaning up" by deleting the file:

```bash
rm hello.txt
terraform plan
```

```
random_pet.name: Refreshing state... [id=definite-koi]
local_file.greeting: Refreshing state... [id=547b3ab13d6a0d2250c6bf25d4e4901dee4982b6]

  # local_file.greeting will be created
  + resource "local_file" "greeting" {
      + content              = "Hello, definite-koi!"
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

The `Refreshing state...` lines are Terraform checking what really exists before it compares. It found the file gone, so the plan puts it back. A difference between your code and reality that Terraform didn't cause is called **drift**. When it happens, you have two honest choices:

- **The hand change was wrong**: `terraform apply` reverts it.
- **The hand change was right**: update `main.tf` to match, so code and reality agree again.

Ignoring drift is the one wrong choice: the next person to run `apply` reverts the change without knowing it was there. Revert it now:

```bash
terraform apply
```

On a cloud, drift is usually a setting changed in the Console rather than a deleted object. You'll see that on a real bucket in [State & Drift](../state/state-basics.md).

## 7. Saved plans: apply exactly what you reviewed

When you run `terraform apply` with no arguments, Terraform computes a **new** plan. If something changed in the meantime, it might not match the plan you reviewed a minute ago. Saving the plan removes that gap:

```bash
terraform plan -out=tfplan    # save the plan to a file
terraform show tfplan         # re-read it any time
terraform apply tfplan        # apply exactly that plan; no prompt, because you already reviewed it
```

If anything changed after the plan was saved, `apply tfplan` refuses to run and you plan again. This is how CI pipelines work: one job saves the plan, a human reviews it, and a later job applies that exact file. You'll build this in [CI/CD](../team-workflow/ci-cd.md). Treat plan files like state: they can contain sensitive values, so don't commit them.

## Checkpoint

Do this **before step 8**, while your resources still exist. Try each part before opening its answer.

### 1. Predict the plan

For each change, decide whether the plan shows `+`, `-/+`, `-`, or no changes, and predict the summary line. Then check with `terraform plan`, **without applying**, and undo the change before the next one.

| Change | Your prediction |
|---|---|
| Run `terraform plan` without changing anything | |
| Change `filename` to `"greeting.txt"` | |
| Give the pet a three-word name: `resource "random_pet" "name" { length = 3 }` | |
| Delete only the `output` block | |

<details>
<summary>Answer</summary>

| Change | Expected result | Summary |
|---|---|---|
| No change | no changes | `No changes.` |
| Change `filename` | `-/+` for `local_file.greeting` | `1 to add, 0 to change, 1 to destroy` |
| `length = 3` | `-/+` for **both** `random_pet.name` and `local_file.greeting` | `2 to add, 0 to change, 2 to destroy` |
| Delete the output | no resource changes, only `Changes to Outputs: - pet_name` | no `Plan:` line; outputs only |

The third one is the important lesson: you edited one resource, but the file is replaced too, because its content depends on the name. Always look at *everything* a plan touches, not just the resource you edited.

</details>

### 2. Break it, read the error, fix it

Misspell the reference as `${random_pet.nmae.id}` and run `terraform validate`. Which part of the address is wrong, and how does the error tell you?

<details>
<summary>Answer</summary>

```
Error: Reference to undeclared resource

  on main.tf line 5, in resource "local_file" "greeting":
   5:   content  = "Hello, ${random_pet.nmae.id}!"

A managed resource "random_pet" "nmae" has not been declared in the root
module.
```

The resource type `random_pet` is right; the local name `nmae` isn't declared. The error gives the file, the line, and the exact name it couldn't find. Fix the spelling and validate again.

</details>

### 3. Explain the workflow

Answer in your own words:

1. Why does Terraform need a state file if `main.tf` already describes what you want?
2. Why does a second `apply` normally do nothing?
3. When do you need to run `terraform init` again?
4. What should you do when a small edit unexpectedly shows `-/+`?

<details>
<summary>Answer</summary>

1. `main.tf` says what you want; state records what Terraform actually created for each address, such as which random name it generated. Without state, Terraform couldn't tell whether `hello.txt` is its file or a stranger's, or what the pet is called.
2. After the first apply, the configuration, the state, and the real files agree, so there's nothing to change.
3. When you add a provider (as with `random`) or a module, or change the backend. Not for ordinary edits.
4. Stop. Read the line marked `# forces replacement`, check what else is replaced along with it, and decide whether losing and recreating it is acceptable. Don't apply just because the edit looked small.

</details>

## 8. `terraform destroy`: remove everything

```bash
terraform destroy
```

```
Plan: 0 to add, 0 to change, 2 to destroy.

Changes to Outputs:
  - pet_name = "definite-koi" -> null

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

local_file.greeting: Destroying... [id=547b3ab13d6a0d2250c6bf25d4e4901dee4982b6]
local_file.greeting: Destruction complete after 0s
random_pet.name: Destroying... [id=definite-koi]
random_pet.name: Destruction complete after 0s

Destroy complete! Resources: 2 destroyed.
```

The order is the reverse of creation: the file goes before the name it depends on. `hello.txt` is gone.

`destroy` removes **every resource in this configuration's state**, and nothing else. It never touches things Terraform didn't create, even in the same directory or, on a cloud, the same project. To preview a destroy without doing it, run `terraform plan -destroy`.

## Best practices

- **Read the summary line and look for `-` and `-/+`** in every plan before typing `yes`. Look for `# forces replacement` to see why, and check what else is replaced with it.
- **Never change managed things by hand.** If you must during an incident, bring the code back in line straight after.
- **Commit `.terraform.lock.hcl`; never commit `.terraform/`, `*.tfstate`, or saved plans.**
- **Run `terraform fmt` and `terraform validate` before every commit.** They're instant, and CI will run them anyway (see [Testing & Code Quality](../team-workflow/testing-and-quality.md)).
- **Use `plan -out` + `apply <planfile>`** whenever someone else reviews the plan or automation applies it.

## Clean up

If you skipped step 8, destroy everything now, then remove the practice directory:

```bash
terraform destroy
cd ~ && rm -rf ~/terraform-first
```

Nothing here costs money, but tear down what you create at the end of every chapter anyway. It's the habit that keeps GPU node pools from running all weekend in Part 5.

---

[← Setup](setup.md) · [↑ Contents](../../README.md) · [Anatomy of HCL →](hcl-anatomy.md)
