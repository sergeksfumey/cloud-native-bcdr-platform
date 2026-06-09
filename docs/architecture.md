# Architecture Notes -- Cloud-Native BCDR Platform

## Active-Passive vs Active-Active Decision

Active-passive selected for this architecture:
- Secondary region compute NOT running during normal operations
- Compute activated by ASR failover when triggered
- 2-hour RTO acceptable for Tier 1 workloads
- Significantly lower cost than active-active (no duplicate running compute)

Active-active justified only for:
- Tier 0 workloads where zero RTO is a hard requirement
- Revenue-generating services where downtime cost exceeds doubled infrastructure cost

## ASR vs Azure Backup -- When to Use Which

Regional outage (East US region failure):
- Use ASR failover to Central US secondary region
- VMs activate in Central US from replicated state
- Network mapping ensures automatic IP assignment in recovery network
- Target RTO: 2 hours

Ransomware / data corruption:
- DO NOT use ASR failover -- ASR replicates all writes including malicious ones
- ASR secondary region has the same encrypted/corrupted data within RPO window
- Use Azure Backup restore from pre-infection recovery point
- Identify infection timestamp, restore from backup point before that timestamp

Accidental deletion / file corruption:
- Use Azure Backup file/folder or VM restore
- ASR does not provide granular file-level recovery

## Secondary Region Infrastructure Maintenance

Secondary region infrastructure must stay in sync with primary region changes.

When primary region changes:
- New subnet added: add equivalent subnet to recovery-vnet via Terraform
- NSG rule updated: update nsg-recovery via Terraform
- Load balancer config changed: update lb-recovery-standby

Drift detection:
- Scheduled terraform plan runs comparing primary/secondary state
- Alert on plan output showing drift between regions

Manual check before DR test:
  az network vnet show --name recovery-vnet --resource-group rg-bcdr-recovery-prod
  Compare output to production-vnet configuration

## Multi-VM Consistency Groups

Related VMs must be grouped in ASR multi-VM consistency groups:
- Without groups: web/app/db VMs may replicate to different timestamps
- Application-inconsistent recovery: database at T-5min, app at T-3min, web at T-1min
- With consistency group: all three replicate to same crash-consistent point

Performance impact:
- App-consistent snapshots require VSS quiescence on Windows VMs
- At 1-hour frequency for Tier 1: brief performance dip during snapshot
- Latency-sensitive applications: consider 4-hour app-consistent + 5-min crash-consistent

Configure in ASR: Protection > Replicated items > Manage > Multi-VM consistency

## Test Failover Network Isolation

test-failover-vnet (10.2.0.0/16):
- No peering to production-vnet
- No peering to recovery-vnet
- No VPN or ExpressRoute connectivity
- Internet access: disabled (outbound NSG deny-all)

Recovered VMs in test failover:
- Can validate HTTP health endpoints between themselves
- Cannot reach external APIs, DNS resolvers, on-premises systems
- Validates: VM starts, application service starts, health endpoint responds
- Does NOT validate: full end-to-end transaction processing

Full production traffic validation requires planned failover -- not test failover.
Document this limitation in DR test reports for audit purposes.

## Recovery Plan Maintenance

Recovery plans must be updated when:
- New VMs added to protected workload group
- VM dependencies change (new service dependency between tiers)
- Recovery group sequencing changes
- Validation script endpoints change

Recovery plan drift is a primary cause of DR test failure.
Treat recovery plan updates as infrastructure changes:
- Code review required
- Test in non-production before applying to production plan
- Document change in DR test runbook
