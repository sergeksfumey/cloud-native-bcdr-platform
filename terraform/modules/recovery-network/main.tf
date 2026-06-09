# =============================================================================
# Module: recovery-network
# Description: Secondary region network infrastructure -- preconfigured before incidents
#
# WHY PRECONFIGURE: Cold-start Terraform deployment adds 15-30 minutes to RTO
# before ASR failover can begin. Preconfigured VNets, NSGs, and LB means
# failover starts immediately -- compute activates via ASR, network is ready.
#
# Infrastructure drift risk: if primary region changes (new subnets, NSG updates)
# are not replicated to secondary, failover may fail. Monitor via scheduled
# terraform plan runs comparing primary and secondary state.
# =============================================================================

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.80" }
  }
}

# Recovery VNet -- mirrors primary region address space on different CIDR
resource "azurerm_virtual_network" "recovery" {
  name                = "recovery-vnet"
  resource_group_name = var.recovery_resource_group
  location            = var.recovery_location
  address_space       = [var.recovery_vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "recovery_workload" {
  name                 = "recovery-subnet"
  resource_group_name  = var.recovery_resource_group
  virtual_network_name = azurerm_virtual_network.recovery.name
  address_prefixes     = [var.recovery_workload_subnet_cidr]
}

resource "azurerm_subnet" "recovery_management" {
  name                 = "recovery-management-subnet"
  resource_group_name  = var.recovery_resource_group
  virtual_network_name = azurerm_virtual_network.recovery.name
  address_prefixes     = [var.recovery_management_subnet_cidr]
}

# NSG -- mirrors primary region security rules
resource "azurerm_network_security_group" "recovery" {
  name                = "nsg-recovery"
  resource_group_name = var.recovery_resource_group
  location            = var.recovery_location
  tags                = var.tags

  security_rule {
    name                       = "Allow-Admin-RDP-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["3389", "22"]
    source_address_prefixes    = var.admin_ip_ranges
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "recovery" {
  subnet_id                 = azurerm_subnet.recovery_workload.id
  network_security_group_id = azurerm_network_security_group.recovery.id
}

# Standby load balancer -- activated during failover
resource "azurerm_lb" "recovery" {
  name                = "lb-recovery-standby"
  resource_group_name = var.recovery_resource_group
  location            = var.recovery_location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "recovery-frontend"
    subnet_id                     = azurerm_subnet.recovery_workload.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Test failover isolated network -- no production connectivity
resource "azurerm_virtual_network" "test_failover" {
  name                = "test-failover-vnet"
  resource_group_name = var.recovery_resource_group
  location            = var.recovery_location
  address_space       = [var.test_failover_vnet_cidr]
  tags                = merge(var.tags, { purpose = "dr-test-isolation" })
}

resource "azurerm_subnet" "test_failover" {
  name                 = "test-failover-subnet"
  resource_group_name  = var.recovery_resource_group
  virtual_network_name = azurerm_virtual_network.test_failover.name
  address_prefixes     = [var.test_failover_subnet_cidr]
}

output "recovery_vnet_id" { value = azurerm_virtual_network.recovery.id }
output "recovery_vnet_name" { value = azurerm_virtual_network.recovery.name }
output "test_failover_vnet_id" { value = azurerm_virtual_network.test_failover.id }
output "recovery_subnet_id" { value = azurerm_subnet.recovery_workload.id }
