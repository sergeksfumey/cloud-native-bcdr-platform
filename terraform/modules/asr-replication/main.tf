# =============================================================================
# Module: asr-replication
# Description: Azure Site Recovery multi-region replication configuration
# Primary: East US -> Secondary: Central US (active-passive)
# Secondary compute NOT running until ASR failover activation
# =============================================================================

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.80" }
  }
}

resource "azurerm_recovery_services_vault" "asr" {
  name                = "rsv-asr-${var.environment}"
  resource_group_name = var.recovery_resource_group
  location            = var.recovery_location
  sku                 = "Standard"
  soft_delete_enabled = true
  tags                = var.tags
}

resource "azurerm_site_recovery_fabric" "primary" {
  name                = "fabric-primary-${var.primary_location}"
  resource_group_name = var.recovery_resource_group
  recovery_vault_name = azurerm_recovery_services_vault.asr.name
  location            = var.primary_location
}

resource "azurerm_site_recovery_fabric" "secondary" {
  name                = "fabric-secondary-${var.recovery_location}"
  resource_group_name = var.recovery_resource_group
  recovery_vault_name = azurerm_recovery_services_vault.asr.name
  location            = var.recovery_location
}

resource "azurerm_site_recovery_protection_container" "primary" {
  name                 = "container-primary"
  resource_group_name  = var.recovery_resource_group
  recovery_vault_name  = azurerm_recovery_services_vault.asr.name
  recovery_fabric_name = azurerm_site_recovery_fabric.primary.name
}

resource "azurerm_site_recovery_protection_container" "secondary" {
  name                 = "container-secondary"
  resource_group_name  = var.recovery_resource_group
  recovery_vault_name  = azurerm_recovery_services_vault.asr.name
  recovery_fabric_name = azurerm_site_recovery_fabric.secondary.name
}

# Tier 1 -- Mission Critical: RPO 15 min, app-consistent 1h, retention 72h
resource "azurerm_site_recovery_replication_policy" "tier1" {
  name                                                 = "policy-tier1-mission-critical"
  resource_group_name                                  = var.recovery_resource_group
  recovery_vault_name                                  = azurerm_recovery_services_vault.asr.name
  recovery_point_retention_in_minutes                  = 4320   # 72 hours
  application_consistent_snapshot_frequency_in_minutes = 60     # 1 hour
}

# Tier 2 -- Business Important: RPO 1h, app-consistent 4h, retention 24h
resource "azurerm_site_recovery_replication_policy" "tier2" {
  name                                                 = "policy-tier2-business-important"
  resource_group_name                                  = var.recovery_resource_group
  recovery_vault_name                                  = azurerm_recovery_services_vault.asr.name
  recovery_point_retention_in_minutes                  = 1440   # 24 hours
  application_consistent_snapshot_frequency_in_minutes = 240    # 4 hours
}

# Tier 3 -- Standard: RPO 4h, app-consistent 6h, retention 15 days
resource "azurerm_site_recovery_replication_policy" "tier3" {
  name                                                 = "policy-tier3-standard"
  resource_group_name                                  = var.recovery_resource_group
  recovery_vault_name                                  = azurerm_recovery_services_vault.asr.name
  recovery_point_retention_in_minutes                  = 21600  # 15 days
  application_consistent_snapshot_frequency_in_minutes = 360    # 6 hours
}

resource "azurerm_site_recovery_protection_container_mapping" "tier1" {
  name                                      = "mapping-tier1"
  resource_group_name                       = var.recovery_resource_group
  recovery_vault_name                       = azurerm_recovery_services_vault.asr.name
  recovery_fabric_name                      = azurerm_site_recovery_fabric.primary.name
  recovery_source_protection_container_name = azurerm_site_recovery_protection_container.primary.name
  recovery_target_protection_container_id   = azurerm_site_recovery_protection_container.secondary.id
  recovery_replication_policy_id            = azurerm_site_recovery_replication_policy.tier1.id
}

# Network mapping -- failed-over VMs receive IPs from recovery network automatically
# No manual network reconfiguration during failover execution
resource "azurerm_site_recovery_network_mapping" "primary_to_recovery" {
  name                        = "netmap-primary-to-recovery"
  resource_group_name         = var.recovery_resource_group
  recovery_vault_name         = azurerm_recovery_services_vault.asr.name
  source_recovery_fabric_name = azurerm_site_recovery_fabric.primary.name
  target_recovery_fabric_name = azurerm_site_recovery_fabric.secondary.name
  source_network_id           = var.primary_vnet_id
  target_network_id           = var.recovery_vnet_id
}

resource "azurerm_monitor_diagnostic_setting" "asr_vault" {
  name                       = "diag-asr-vault"
  target_resource_id         = azurerm_recovery_services_vault.asr.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "AzureSiteRecoveryJobs" }
  enabled_log { category = "AzureSiteRecoveryEvents" }
  enabled_log { category = "AzureSiteRecoveryReplicatedItems" }
  enabled_log { category = "AzureSiteRecoveryReplicationStats" }
  metric { category = "Health"; enabled = true }
}

# Alert: RPO breach approaching for Tier 1 (15-minute threshold)
resource "azurerm_monitor_metric_alert" "rpo_breach_tier1" {
  name                = "alert-asr-rpo-breach-tier1"
  resource_group_name = var.recovery_resource_group
  scopes              = [azurerm_recovery_services_vault.asr.id]
  description         = "ASR RPO lag approaching 15-minute Tier 1 threshold"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.RecoveryServices/vaults"
    metric_name      = "ReplicationLatency"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 900  # 15 minutes in seconds
  }

  action { action_group_id = var.action_group_id }
}

output "asr_vault_id" { value = azurerm_recovery_services_vault.asr.id }
output "asr_vault_name" { value = azurerm_recovery_services_vault.asr.name }
output "tier1_policy_id" { value = azurerm_site_recovery_replication_policy.tier1.id }
output "tier2_policy_id" { value = azurerm_site_recovery_replication_policy.tier2.id }
output "tier3_policy_id" { value = azurerm_site_recovery_replication_policy.tier3.id }
