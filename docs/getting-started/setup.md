# Setup

> Install Terraform. That's all Getting Started and Part 1 need.

---

The first half of this guide runs entirely on your own machine: [Getting Started](core-workflow.md) and [Part 1](../core-language/providers.md) manage local files and generated values, so you need no cloud account yet. You'll set up GCP, with a sandbox project, a budget alert, and credentials, at the start of Part 2 in [Connecting to GCP](../state/google-provider.md#set-up-gcp).

Commands assume Ubuntu, Debian, or WSL2. On macOS, follow the linked official instructions; everything after installation is the same.

## Install Terraform

Install from HashiCorp's apt repository rather than a random binary. That way `apt upgrade` keeps it current, and the package is signature-checked:

```bash
# 1. Install the tools the next steps need
sudo apt-get update
sudo apt-get install -y gnupg software-properties-common curl

# 2. Download HashiCorp's GPG key, used to verify the packages
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# 3. Add HashiCorp's official apt repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 4. Refresh the package list so apt sees the new repository
sudo apt-get update

# 5. Install Terraform
sudo apt-get install -y terraform

# 6. Check the version
terraform version   # Terraform v1.11.0 or newer
```

On macOS: `brew tap hashicorp/tap && brew install hashicorp/tap/terraform`. Other platforms: [Install Terraform](https://developer.hashicorp.com/terraform/install).

Optionally, turn on tab completion for subcommands:

```bash
terraform -install-autocomplete   # then open a new shell
```

> 📌 **This guide targets Terraform 1.11+** (see the badge on the [README](../../README.md)). Each example declares its minimum with `required_version`: `">= 1.10"` for most, `">= 1.11"` for the [Secret Manager](../gcp-foundations/secrets.md) example, which uses write-only arguments. An older binary fails immediately with a clear error instead of misbehaving halfway through.

## Verify

```bash
terraform version   # v1.11+
```

If that prints a version, you're ready for [Core Workflow](core-workflow.md). The first `terraform init` there downloads the providers it needs, so you also need internet access.

## Checkpoint

1. Why install Terraform from HashiCorp's apt repository instead of downloading a binary by hand?
2. An example declares `required_version = ">= 1.11"`, and you have Terraform 1.9. What happens when you run it?

<details>
<summary>Answer</summary>

1. The packages are signature-checked against HashiCorp's GPG key, and `apt upgrade` keeps Terraform current along with the rest of your system.
2. Terraform stops immediately with an error naming the required version, before reading state or planning anything. Upgrade Terraform and run it again.

</details>

## Best practices

- **Install from the official repository** (or Homebrew on macOS), not from a copied binary.
- **Pin your Terraform version** with `required_version` in every configuration, so teammates and CI run the same major behavior.

---

[← What is Terraform?](what-is-terraform.md) · [↑ Contents](../../README.md) · [Core Workflow →](core-workflow.md)
