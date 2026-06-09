# =============================================================================
# Module: backup-vault
# Description: Immutable Azure Backup Recovery Services Vault
#
# KEY DISTINCTION -- ASR vs Azure Backup:
# ASR = availability recovery (regional outage, fast RTO)
# Azure Backup = data protection (corruption, ransomware, compliance retention)
#
# ASR faithfully replicates ransomware encryption to secondary region.
# Ransomware recovery = Azure Backup restore from pre-infection point.
# NOT ASR failover to secondary region.
# =============================================================================

terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm"; version = "~> 3.80" }
  }
}

resource "azurerm_recovery_services_vault" "backup" {
  name                = "rsv-backup-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"

  # Compliance-mode immutability: prevents vault deletion and backup modification
  # even by subscription administrators -- tamper-proof ransomware protection
  # WARNING: cannot be disabled after enabling in compliance mode
  immutability = var.immutability_state

  soft_delete_enabled = true  # 14-day soft delete as secondary protection layer

  tags = var.tags
}

# VM backup policy: daily operational + weekly/monthly compliance retention
resource "azurerm_backup_policy_vm" "standard" {
  name                = "bp-vm-standard-${var.environment}"
  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.backup.name
  timezone            = "UTC"

  backup {
    frequency = "Daily"
    time      = "02:00"
  }

  retention_daily { count = 30 }   # 30-day daily for operational recovery

  retention_weekly {
    count    = 52                   # 52-week weekly for compliance retention
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }

  retention_yearly {
    count    = 7
    weekdays = ["Sunday"]
    weeks    = ["First"]
    months   = ["January"]
  }
}

resource "azurerm_monitor_diagnostic_setting" "backup_vault" {
  name                       = "diag-backup-vault"
  target_resource_id         = azurerm_recovery_services_vault.backup.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "AzureBackupReport" }
  enabled_log { category = "CoreAzureBackup" }
  enabled_log { category = "AddonAzureBackupJobs" }
  enabled_log { category = "AddonAzureBackupAlerts" }
  enabled_log { category = "AddonAzureBackupPolicy" }
  metric { category = "Health"; enabled = true }
}

# Alert: backup job failure
resource "azurerm_monitor_metric_alert" "backup_failure" {
  name                = "alert-backup-job-failure"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_recovery_services_vault.backup.id]
  description         = "Azure Backup job failure detected"
  severity            = 1
  frequency           = "PT1H"
  window_size         = "PT1H"

  criteria {
    metric_namespace = "Microsoft.RecoveryServices/vaults"
    metric_name      = "BackupHealthEvent"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action { action_group_id = var.action_group_id }
}

output "backup_vault_id" { value = azurerm_recovery_services_vault.backup.id }
output "backup_vault_name" { value = azurerm_recovery_services_vault.backup.name }
output "vm_backup_policy_id" { value = azurerm_backup_policy_vm.standard.id }
