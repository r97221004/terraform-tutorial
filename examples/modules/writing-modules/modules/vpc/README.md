# vpc

A custom-mode VPC for a VPC-native GKE cluster: one regional subnet with
secondary ranges for Pods and Services, Private Google Access, optional
Cloud NAT, and firewall rules for internal traffic and SSH through IAP.

```hcl
module "network" {
  source = "./modules/vpc"

  project_id = var.project_id
  name       = "ml-vpc"
  region     = "us-central1"
  ip_ranges = {
    nodes    = "10.10.0.0/20"
    pods     = "10.16.0.0/14"
    services = "10.10.16.0/20"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | required | Project to create the network in. |
| `name` | `string` | required | VPC name; other names are derived from it. |
| `region` | `string` | required | Region for the subnet, router, and NAT. |
| `ip_ranges` | `object({ nodes, pods, services })` | required | Primary and secondary CIDR ranges. |
| `enable_nat` | `bool` | `true` | Create Cloud Router + NAT. |
| `iap_ssh_target_tags` | `list(string)` | `["allow-iap-ssh"]` | Tags that may be reached over SSH through IAP. Empty disables the rule. |

## Outputs

| Name | Description |
|---|---|
| `network_id`, `network_name` | The VPC. |
| `subnet_id`, `subnet_name` | The GKE subnet. |
| `pods_range_name`, `services_range_name` | Secondary range names for GKE's `ip_allocation_policy`. |

The module doesn't configure a provider or enable APIs: the caller does both.

## Tests

```bash
terraform init
terraform test   # plan-only unit tests with a mocked provider; no credentials needed
```
