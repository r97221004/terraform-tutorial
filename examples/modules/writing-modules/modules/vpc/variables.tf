variable "project_id" {
  description = "Project to create the network in."
  type        = string
}

variable "name" {
  description = "VPC name. Subnet, router, NAT, and firewall names are derived from it."
  type        = string

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,40}[a-z0-9])?$", var.name))
    error_message = "name must be 1-42 characters: lowercase letters, digits, and hyphens, starting with a letter."
  }
}

variable "region" {
  description = "Region for the subnet, router, and NAT."
  type        = string
}

variable "ip_ranges" {
  description = "Primary range for nodes, and secondary ranges for GKE Pods and Services."
  type = object({
    nodes    = string
    pods     = string
    services = string
  })

  validation {
    condition     = alltrue([for r in values(var.ip_ranges) : can(cidrnetmask(r))])
    error_message = "Every value in ip_ranges must be an IPv4 CIDR block, such as 10.10.0.0/20."
  }
}

variable "enable_nat" {
  description = "Create Cloud Router + NAT so nodes without public IPs can reach the internet."
  type        = bool
  default     = true
}

variable "iap_ssh_target_tags" {
  description = "Network tags of VMs that may be reached over SSH through IAP. Empty disables the rule."
  type        = list(string)
  default     = ["allow-iap-ssh"]
}
