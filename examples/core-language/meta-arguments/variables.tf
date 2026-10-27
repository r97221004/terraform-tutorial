variable "datasets" {
  description = "One manifest per dataset stage. The map key becomes part of the file name."
  type = map(object({
    storage_class  = optional(string, "STANDARD")
    retention_days = optional(number)
  }))
  default = {
    raw     = { storage_class = "NEARLINE", retention_days = 90 }
    curated = {}
    eval    = { retention_days = 30 }
  }
}

variable "models" {
  description = "Models to publish a model card for."
  type        = set(string)
  default     = ["llama-3-1-8b", "qwen2-5-7b"]
}

variable "enable_scratch" {
  description = "Create a scratch area for experiments."
  type        = bool
  default     = true
}
