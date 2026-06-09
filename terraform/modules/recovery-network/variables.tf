variable "recovery_resource_group" { type = string }
variable "recovery_location" { type = string; default = "centralus" }
variable "recovery_vnet_cidr" { type = string; default = "10.1.0.0/16" }
variable "recovery_workload_subnet_cidr" { type = string; default = "10.1.0.0/24" }
variable "recovery_management_subnet_cidr" { type = string; default = "10.1.1.0/28" }
variable "test_failover_vnet_cidr" { type = string; default = "10.2.0.0/16" }
variable "test_failover_subnet_cidr" { type = string; default = "10.2.0.0/24" }
variable "admin_ip_ranges" { type = list(string) }
variable "tags" { type = map(string); default = {} }
