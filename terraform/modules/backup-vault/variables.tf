variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "immutability_state" {
  type        = string
  default     = "Unlocked"
  description = "Unlocked (reversible) or Locked (compliance mode -- irreversible). Use Locked for production."
  validation {
    condition     = contains(["Disabled", "Unlocked", "Locked"], var.immutability_state)
    error_message = "Must be Disabled, Unlocked, or Locked"
  }
}
variable "log_analytics_workspace_id" { type = string }
variable "action_group_id" { type = string }
variable "tags" { type = map(string); default = {} }
