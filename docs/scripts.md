---
layout: default
title: PowerShell Scripts Reference
---

# PowerShell Scripts Reference

This guide documents the PowerShell scripts included in the `scripts/` folder and how to use them for managing your Azure Virtual Desktop deployment.

## Overview

| Script | Purpose | Typical Frequency |
|--------|---------|-------------------|
| `Deploy-AvdOccasional.ps1` | Deploy or update all infrastructure | Once (or when scaling) |
| `Start-AvdOccasional.ps1` | Start deallocated session host VMs | Before working session |
| `Stop-AvdOccasional.ps1` | Deallocate VMs and clean up costs | After working session |
| `Remove-AvdOccasional.ps1` | Delete all resources permanently | When no longer needed |
| `Test-AvdSessionHost.ps1` | Diagnose session host connectivity issues | When troubleshooting problems |

## Deploy-AvdOccasional.ps1

**Purpose:** Deploy or update Azure Virtual Desktop infrastructure using Bicep templates.

**When to use:**
- Initial deployment.
- Scaling (adding more VMs).
- Changing workload size (light ↔ moderate).
- Redeploy after resource deletion.
- Apply configuration updates.

### Basic Usage

```powershell
# Deploy with interactive password prompt (recommended)
.\scripts\Deploy-AvdOccasional.ps1

# Deploy with secure string password
$adminPassword = ConvertTo-SecureString 'YourPassword123!' -AsPlainText -Force
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword

# Dry-run: see what would be created without making changes
.\scripts\Deploy-AvdOccasional.ps1 -WhatIf

# Dry-run with secure password
$adminPassword = Read-Host "Enter password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword -WhatIf
```

### Parameters

| Parameter | Type | Default | Required | Notes |
|-----------|------|---------|----------|-------|
| `AdminPassword` | SecureString | (prompted) | No* | VM admin password. If not supplied, prompted interactively. |
| `AdminUsername` | String | `avdadmin` | No | VM admin username. Alphanumeric, can contain `.`, `-`, `_`. |
| `Environment` | String | `dev` | No | Environment name prefix for resources (`dev`, `test`, `prod`). |
| `WorkloadSize` | String | `moderate` | No | VM SKU: `light` (B2s, ~£35/mo) or `moderate` (D2s_v3, ~£100/mo). |
| `VmCount` | Int | `1` | No | Number of session host VMs (1–5). Each adds ~£100/mo active. |
| `Location` | String | `ukwest` | No | Azure region (e.g., `northeurope`, `eastus`). |
| `WhatIf` | Switch | N/A | No | Preview changes without applying. Use with `-WhatIf -Verbose` for detailed output. |

### Examples

**Deploy test environment with 2 light workload VMs:**

```powershell
$adminPassword = Read-Host "Enter password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 `
  -Environment test `
  -WorkloadSize light `
  -VmCount 2 `
  -Location northeurope `
  -AdminPassword $adminPassword
```

**Scale from 1 to 3 VMs (productive environment added):**

```powershell
.\scripts\Deploy-AvdOccasional.ps1 `
  -Environment prod `
  -VmCount 3 `
  -WorkloadSize moderate `
  -AdminPassword (Read-Host "Enter password" -AsSecureString)
```

**Preview deployment before running:**

```powershell
$adminPassword = Read-Host "Enter password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 `
  -AdminPassword $adminPassword `
  -WhatIf -Verbose
```

**Deployment Time**

- **Initial deployment**: 15–20 minutes (includes VM creation, agent installation, Entra ID joining).
- **Rerun (no changes)**: 3–5 minutes (validates existing resources).
- **Scaling (add VMs)**: 10–15 minutes (new VMs only).

### Behind the Scenes

1. Creates Azure Resource Group: `avd-occasional-rg`.
2. Compiles Bicep templates (`infra/main.bicep` and modules).
3. Validates template against Azure.
4. Deploys resources in dependency order:
   - Network infrastructure (VNet, NSG, Subnet).
   - Azure Virtual Desktop (Host Pool, Workspace, Application Group).
   - Session Host VMs.
   - Public IPs.
   - Custom Script extensions (installs AVD Agent, performs Entra ID join).
5. Validates deployment completion.

### Troubleshooting

See [Troubleshooting Guide: Deployment Issues](troubleshooting.md#deployment-issues).

---

## Start-AvdOccasional.ps1

**Purpose:** Start deallocated session host VMs and recreate public IP addresses.

**When to use:**
- Before beginning a working session
- After using `Stop-AvdOccasional.ps1`
- When resuming work after shutdown

**Why both the script and manual start exist:**
- Script automates Public IP recreation (required for outbound connectivity).
- Manual `az vm start` would leave VMs without outbound access.

### Basic Usage

```powershell
# Start VMs (returns immediately after triggering startup)
.\scripts\Start-AvdOccasional.ps1

# Start and wait for VMs to be fully running (recommended for automation)
.\scripts\Start-AvdOccasional.ps1 -WaitForStartup
```

### Parameters

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `WaitForStartup` | Switch | N/A | Block until VMs fully running. Useful for scripts and automation. |

### What It Does

1. Lists all deallocated VMs in resource group
2. Creates new Standard Public IP addresses
3. Associates Public IPs with VM network interfaces
4. Starts all VMs
5. (Optional) Waits for VMs to power on and respond
6. Displays final status

### Examples

**Quick start before working:**

```powershell
.\scripts\Start-AvdOccasional.ps1
```

**Start and wait for full startup (for CI/CD or scheduled tasks):**

```powershell
.\scripts\Start-AvdOccasional.ps1 -WaitForStartup
```

Subsequent commands can assume VMs are running.

### Expected Output

```
Starting Azure Virtual Desktop VMs for resource group 'avd-occasional-rg'...
Creating Public IP addresses...
  - avd-dev-pip-0 created
Starting VMs...
  - avd-dev-vm-0 started
  - avd-dev-vm-0: PowerState/running (after ~45 seconds)
✓ All VMs started successfully
VM Status:
  Name              PowerState   ProvisioningState
  avd-dev-vm-0      running      Succeeded
```

### Startup Time

- **Creating Public IPs**: 10–20 seconds
- **VM power-on**: 30–60 seconds
- **Fully booted and running**: 90–180 seconds
- **Total**: 2–3 minutes

### Troubleshooting

See [Troubleshooting Guide: Connection Issues](troubleshooting.md#connection-issues).

---

## Stop-AvdOccasional.ps1

**Purpose:** Deallocate session host VMs and delete public IP addresses to save costs.

**When to use:**
- After finishing a working session
- At end of day
- Before extended time away
- To save ~98% on compute costs

**Important:** Deallocating (not deleting) preserves all data and configuration; VMs resume in 2–3 minutes with `Start-AvdOccasional.ps1`.

### Basic Usage

```powershell
# Stop VMs (delete Public IPs to save costs)
.\scripts\Stop-AvdOccasional.ps1

# Stop without confirmation (useful for scheduled tasks)
.\scripts\Stop-AvdOccasional.ps1 -Force
```

### Parameters

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `Force` | Switch | N/A | Skip confirmation prompt and proceed with stop. |

### What It Does

1. Displays summary of VMs to stop
2. Prompts for confirmation (unless `-Force` specified)
3. Disassociates Public IPs from VM network interfaces
4. Deletes all Public IP resources (saves ~£2–3/month per VM)
5. Deallocates (stops compute) all VMs
6. Displays final status

### Examples

**Stop after work (with confirmation):**

```powershell
.\scripts\Stop-AvdOccasional.ps1

# When prompted:
# Stopping VMs will delete public IPs to save costs. Continue? (Y/N):
# > Y
```

**Stop without confirmation (for automation/scheduled tasks):**

```powershell
.\scripts\Stop-AvdOccasional.ps1 -Force
```

**Via scheduled task (e.g., stop automatically at 5 PM):**

```powershell
# In Task Scheduler, set to run:
& "C:\path\to\avd-occasional\scripts\Stop-AvdOccasional.ps1" -Force
```

### Expected Output

```
Stopping Azure Virtual Desktop VMs for resource group 'avd-occasional-rg'...

VMs to stop (deallocate):
  - avd-dev-vm-0

Public IPs to delete (cost savings ~£2-3/month):
  - avd-dev-pip-0

Continue? (Y/N): Y

Deleting public IP addresses...
  - avd-dev-pip-0 deleted
Deallocating VMs...
  - avd-dev-vm-0 deallocated
✓ All VMs stopped successfully
Estimated monthly savings: £2-3
```

### Cost Implications

After running Stop script:

| Item | Monthly Cost Before | After | Savings |
|------|---------------------|-------|---------|
| Compute (VM) | £90–120 | £0 | 100% |
| Public IP | £2–3 | £0 | 100% |
| OS Disk | £2–3 | £2–3 | 0% |
| **Total** | **£94–126** | **£2–3** | **~98%** |

Deallocated state is cost-optimised and can last indefinitely without additional charges.

### Resuming After Stop

```powershell
# Start VMs again (recreates Public IPs)
.\scripts\Start-AvdOccasional.ps1 -WaitForStartup

# Connect to your desktop in Windows App (same machine, same configuration)
```

---

## Remove-AvdOccasional.ps1

**Purpose:** Permanently delete all infrastructure and resources (cannot be undone).

**When to use:**
- Ending project or testing phase
- Cleaning up test deployments
- Reducing to zero infrastructure cost

**⚠️ WARNING:** Deletion is permanent. All VMs, disks, networking, and AVD resources will be deleted. Recovery is not possible.

### Basic Usage

```powershell
# Delete with confirmation prompt (recommended)
.\scripts\Remove-AvdOccasional.ps1

# Delete without confirmation (caution: no safety prompt)
.\scripts\Remove-AvdOccasional.ps1 -Force
```

### Parameters

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `Force` | Switch | N/A | Skip confirmation and proceed immediately with deletion. |

### What It Does

1. Displays resource group and resource summary
2. Prompts for confirmation (unless `-Force` specified)
3. Deletes entire resource group (`avd-occasional-rg`) and **all contents**

### Examples

**Delete with confirmation (safe):**

```powershell
.\scripts\Remove-AvdOccasional.ps1

# Prompt:
# This will DELETE all AVD infrastructure in resource group 'avd-occasional-rg'.
# VMs, disks, networking, and AVD services will be permanently removed.
# Type 'yes' to confirm or press Ctrl+C to cancel: 
# > yes
```

**Force delete without confirmation (for automation, use caution):**

```powershell
.\scripts\Remove-AvdOccasional.ps1 -Force
```

### Expected Output

```
Deleting Azure Virtual Desktop infrastructure...

Resource group: avd-occasional-rg
Resources to delete:
  - Virtual Network
  - Network Security Group
  - Session Host VMs (1)
  - Public IPs (0)
  - Host Pool
  - Workspace
  - Application Group

This action is PERMANENT and cannot be undone. Continue? (Y/N): Y

Deleting resource group 'avd-occasional-rg'...
✓ Resource group deleted successfully
Infrastructure removed. Cost impact: £0 going forward.
```

### Recovery After Deletion

**To restore deleted infrastructure:**

```powershell
# Redeploy (creates fresh infrastructure with new Public IPs)
$adminPassword = Read-Host "Enter password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword
```

Redeploy creates new resources; recreated VMs will have new public IP addresses and names but same internal configuration.

---

## Test-AvdSessionHost.ps1

**Purpose:** Diagnose session host connectivity and status issues by checking VM power state, extensions, AVD registration, and Entra ID join configuration.

**When to use:**
- Session host status shows as unavailable or unhealthy.
- Cannot connect to desktop in Windows App.
- After VM restart or redeployment.
- When verifying post-deployment configuration.

### Basic Usage

```powershell
# Auto-discover and diagnose (recommended)
.\scripts\Test-AvdSessionHost.ps1

# Specific resource group
.\scripts\Test-AvdSessionHost.ps1 -ResourceGroupName avd-occasional-rg

# Specific host pool and VM
.\scripts\Test-AvdSessionHost.ps1 `
  -ResourceGroupName avd-occasional-rg `
  -HostPoolName avd-dev-hp-zx4itrg75d2kc `
  -VmName avd-dev-vm-0-zx4itrg75d2kc
```

### Parameters

| Parameter | Type | Default | Notes |
|-----------|------|---------|-------|
| `ResourceGroupName` | String | `avd-occasional-rg` | Resource group containing AVD resources. |
| `HostPoolName` | String | (auto-discovered) | AVD host pool name. Auto-discovered if not specified. |
| `VmName` | String | (auto-discovered) | Session host VM name. Auto-discovered if not specified. |

### What It Checks

1. **VM Power State** — Whether VM is running or deallocated.
2. **VM Extensions** — Status of AADLoginForWindows and DSC extensions.
3. **AVD Session Host Status** — Checks if session host is registered and Available in the host pool.
4. **RDP Properties** — Verifies Entra ID authentication is configured (targetisaadjoined:i:1).
5. **Entra ID Join** — Confirms AADLoginForWindows extension is installed and active.
6. **Heartbeat** — Checks when AVD agent last reported (indicates agent health).

### Example Output

```
=== AVD Session Host Diagnostics ===
Auto-discovering AVD resources in resource group: avd-occasional-rg

Discovering host pool...
  Found: avd-dev-hp-zx4itrg75d2kc
Discovering VMs...
  Found: avd-dev-vm-0-zx4itrg75d2kc

Resource Group: avd-occasional-rg
Host Pool: avd-dev-hp-zx4itrg75d2kc
VM Name: avd-dev-vm-0-zx4itrg75d2kc

Checking VM power state...
  Power State: VM running

Checking VM extensions...
  [AADLoginForWindows]: Succeeded
  [avd-dev-vm-0-AddSessionHost]: Succeeded

Checking session host status in AVD...
  Status: Available
  Update State: Latest
  Last Heartbeat: 2026-02-23T14:30:45.1234567Z
  OS Version: Windows 11 Enterprise

Checking host pool RDP properties...
  Custom RDP Properties: targetisaadjoined:i:1;enablerdsaadauth:i:1
  Entra ID auth properties: CONFIGURED

Checking Entra ID join status...
  AADLoginForWindows extension: Succeeded

=== Recommendations ===
• Session host is Available and ready for connections!
```

### Interpreting Results

**If Power State is "VM deallocated":**
- Start the VM: `.\scripts\Start-AvdOccasional.ps1`

**If Session Host Status is not "Available":**
- Check if extensions are Succeeded (all should show green)
- Verify last heartbeat is recent (within 5 minutes means agent is active)
- If heartbeat is old (>15 minutes), restart the VM

**If Entra ID auth is "MISSING":**
- Host pool RDP properties need updating
- Redeploy using: `.\scripts\Deploy-AvdOccasional.ps1`

**If heartbeat is excessive (>15 minutes old):**
- AVD agent may have crashed; restart VM:
  ```powershell
  .\scripts\Stop-AvdOccasional.ps1 -Force
  .\scripts\Start-AvdOccasional.ps1 -WaitForStartup
  ```

### Troubleshooting with Test Results

See [Troubleshooting Guide: Diagnosis Steps](troubleshooting.md#diagnosis-with-test-avdsessionhost) for interpreting specific diagnostic results.

---

## Manual Alternatives

### Start VMs Without Script

```powershell
# Create Public IPs manually
foreach ($vm in (az vm list --resource-group avd-occasional-rg --query '[].name' -o tsv)) {
    $nic = (az vm nic list --resource-group avd-occasional-rg --vm-name $vm --query '[0].id' -o tsv)
    az network public-ip create --resource-group avd-occasional-rg `
      --name "pip-$vm" --sku Standard
}

# Start VMs using Azure CLI
az vm start --resource-group avd-occasional-rg --ids @(
    az vm list --resource-group avd-occasional-rg --query '[].id' -o tsv
)
```

**Note:** Manual approach is more tedious; scripts are recommended.

### Stop VMs Without Script

```powershell
# Deallocate VMs
az vm deallocate --resource-group avd-occasional-rg --ids @(
    az vm list --resource-group avd-occasional-rg --query '[].id' -o tsv
)

# Delete Public IPs
foreach ($pip in (az network public-ip list --resource-group avd-occasional-rg --query '[].id' -o tsv)) {
    az network public-ip delete --ids $pip
}
```

---

## Scheduling Scripts

### Windows Task Scheduler (Automated Stop at End of Day)

1. Open **Task Scheduler**
2. Create new task:
   - **Name**: "Stop AVD After Hours"
   - **Trigger**: Daily at 5 PM
   - **Action**: Run PowerShell script:
     ```
     Program: PowerShell.exe
     Arguments: -NoProfile -ExecutionPolicy Bypass -Command "& 'C:\path\to\avd-occasional\scripts\Stop-AvdOccasional.ps1' -Force"
     ```
3. Set user and security options, then save

### Azure Automation (Serverless Scheduling)

For enterprise deployments, consider [Azure Automation Runbooks](https://learn.microsoft.com/en-us/azure/automation/) to schedule Start/Stop via the cloud without local scripts.

---

## Troubleshooting Scripts

See [Troubleshooting Guide: Script Issues](troubleshooting.md#script--automation-issues).

---

**Related Documentation:**
- [Quick Start](quickstart.md)
- [Deployment Details](deployment-detailed.md)
- [Architecture Overview](architecture.md)

---

**Last Updated**: February 2026
