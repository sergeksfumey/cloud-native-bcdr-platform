# =============================================================================
# Environment: Production
# Description: Cloud-Native BCDR Platform
# Primary: East US | Secondary (DR): Central US
# =============================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.80" }
  }
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-prod"
    storage_account_name = "stgtfstateprod001"
    container_name       = "tfstate"
    key                  = "bcdr-platform/prod.tfstate"
  }
}

provider "azurerm" { features {} }

resource "azurerm_resource_group" "primary" {
  name     = "rg-bcdr-primary-prod"
  location = "eastus"
  tags     = local.tags
}

resource "azurerm_resource_group" "recovery" {
  name     = "rg-bcdr-recovery-prod"
  location = "centralus"
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-bcdr-prod"
  resource_group_name = azurerm_resource_group.primary.name
  location            = azurerm_resource_group.primary.location
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.tags
}

resource "azurerm_monitor_action_group" "bcdr_ops" {
  name                = "ag-bcdr-ops-prod"
  resource_group_name = azurerm_resource_group.primary.name
  short_name          = "bcdrops"

  email_receiver {
    name          = "bcdr-team"
    email_address = var.ops_email
  }
}

# Primary VNet
resource "azurerm_virtual_network" "primary" {
  name                = "production-vnet"
  resource_group_name = azurerm_resource_group.primary.name
  location            = azurerm_resource_group.primary.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

module "recovery_network" {
  source                  = "../../modules/recovery-network"
  recovery_resource_group = azurerm_resource_group.recovery.name
  recovery_location       = "centralus"
  admin_ip_ranges         = var.admin_ip_ranges
  tags                    = local.tags
}

module "asr_replication" {
  source                     = "../../modules/asr-replication"
  environment                = "prod"
  primary_location           = "eastus"
  recovery_location          = "centralus"
  recovery_resource_group    = azurerm_resource_group.recovery.name
  primary_vnet_id            = azurerm_virtual_network.primary.id
  recovery_vnet_id           = module.recovery_network.recovery_vnet_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  action_group_id            = azurerm_monitor_action_group.bcdr_ops.id
  tags                       = local.tags
}

module "backup_vault" {
  source                     = "../../modules/backup-vault"
  environment                = "prod"
  resource_group_name        = azurerm_resource_group.primary.name
  location                   = azurerm_resource_group.primary.location
  immutability_state         = "Locked"  # Compliance mode -- irreversible
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  action_group_id            = azurerm_monitor_action_group.bcdr_ops.id
  tags                       = local.tags
}

locals {
  tags = {
    environment  = "prod"
    project      = "bcdr-platform"
    managed_by   = "terraform"
    owner        = "infrastructure-team"
    cost-centre  = "infrastructure"
  }
}
