variable "environment" { type = string }
variable "primary_location" { type = string; default = "eastus" }
variable "recovery_location" { type = string; default = "centralus" }
variable "recovery_resource_group" { type = string }
variable "primary_vnet_id" { type = string }
variable "recovery_vnet_id" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "action_group_id" { type = string }
variable "tags" { type = map(string); default = {} }
