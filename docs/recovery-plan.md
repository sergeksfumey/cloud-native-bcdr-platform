# Recovery Plan -- Order Processing Workload

## Recovery Plan: order-processing-recovery

Failover sequence -- 4 groups:

Group 1 (execute first -- network and database preparation):
  - Script: validate-recovery-network-connectivity
    Validates: recovery VNet routing, NSG rules, DNS resolution
    Fail condition: network unreachable -- abort failover
  - Script: start-recovery-database-services
    Action: pre-start any recovery-region database dependencies

Group 2 (after Group 1 -- database tier):
  - ASR Failover: vm-db-01
  - Wait: 5 minutes
    Purpose: database startup validation before app tier starts
    Fail condition: database health check fails after wait period

Group 3 (after Group 2 -- application tier):
  - ASR Failover: vm-app-01
  - Wait: 3 minutes
    Purpose: application service startup before web tier starts

Group 4 (after Group 3 -- web tier and completion):
  - ASR Failover: vm-web-01
  - Script: validate-application-health-endpoint
    Validates: HTTP 200 from all application health endpoints
  - Script: update-dns-records-to-recovery-region
    Action: updates DNS A records to point to recovery region IPs
  - Script: notify-operations-team-failover-complete
    Action: sends Teams/email notification with failover summary

## Failback Procedure (after primary region restored)

1. Confirm primary region fully operational
2. Re-enable ASR replication from secondary back to primary (reprotect)
3. Wait for replication to reach Normal health state
4. Schedule planned failback during maintenance window
5. Execute planned failover back to primary region
6. Validate primary region application health
7. Update DNS records back to primary region IPs
8. Confirm ASR replication re-established primary to secondary direction

Failback is a planned operation -- not automated.
Requires governance team approval and change management ticket.
