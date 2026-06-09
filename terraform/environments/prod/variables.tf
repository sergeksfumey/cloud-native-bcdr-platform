variable "ops_email" { type = string }
variable "admin_ip_ranges" { type = list(string); description = "Authorised admin IP ranges for NSG rules" }
