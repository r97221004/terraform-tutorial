variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Free-form owner name. Normalized into a valid label value."
  type        = string
  default     = "ML Platform Team"
}

variable "models" {
  description = "Models to serve. Rendered into the serving config."
  type = list(object({
    name    = string
    repo    = string
    gpus    = optional(number, 1)
    enabled = optional(bool, true)
  }))
  default = [
    { name = "llama-3-1-8b", repo = "meta-llama/Llama-3.1-8B-Instruct" },
    { name = "qwen2-5-7b", repo = "Qwen/Qwen2.5-7B-Instruct" },
    { name = "mixtral-8x7b", repo = "mistralai/Mixtral-8x7B-Instruct-v0.1", gpus = 4, enabled = false },
  ]
}

variable "release_notes" {
  description = "Optional release notes, added to the bundle as NOTES.txt. Empty means no notes file."
  type        = string
  default     = ""
}
