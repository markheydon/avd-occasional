---
layout: default
title: Detailed Deployment Guide
---

# Detailed Deployment Guide

This guide provides comprehensive deployment instructions, architectural context, and advanced configuration options. For quick-start steps, see the [Quick Start Guide](quickstart.md).

## Important Prerequisites

⚠️ **This template deploys Entra ID-Joined session hosts.** VMs authenticate via cloud-based Entra ID (no on-premises AD required). See [Prerequisites Guide: Entra ID Authentication](prerequisites.md#entra-id-authentication) for details.

⚠️ **Role assignments are NOT automatic.** After deployment, users must be assigned two RBAC roles. See [Quick Start: Step 3](quickstart.md#3-assign-role-permissions-required) for instructions.

### Prerequisites Checklist

- [ ] Azure CLI v2.40+ installed.
- [ ] Bicep CLI v0.20+ (included with Azure CLI v2.20+).
- [ ] PowerShell 5.1+.
- [ ] Azure subscription with **Contributor** or **Owner** role.
- [ ] Entra ID tenant access.
- [ ] Strong admin password for session host VMs.

For detailed setup, see [Prerequisites Guide](prerequisites.md).

---

## Deployment Architecture

### Idempotent Design

This template is **fully idempotent**, meaning:

- **Safe redeployment**: Running deployment multiple times creates/updates the same resource set without duplicates.
- **Stable resource names**: Resource names are deterministically derived from the resource group ID using `uniqueString(resourceGroup().id)`.
- **Failed deployment recovery**: If deployment fails midway, simply rerun—only missing resources will be created.
- **CI/CD ready**: Suitable for automated deployment pipelines.

**Technical implementation:**
- All resource names are stable via `uniqueString()`.
- Idempotent operations use `dependsOn` and stable naming.
- No random naming that could cause duplicates.

### Session Host Extension Architecture

The deployment uses two extensions deployed in sequence on each VM:

**1. AADLoginForWindows:**
- Publisher: Microsoft.Azure.ActiveDirectory.
- Purpose: Enables Entra ID authentication and login on the VM.
- Allows users to sign in with their Entra ID credentials.
- Deployed first; must complete before DSC extension.

**2. DSC (Desired State Configuration):**
- Publisher: Microsoft.Powershell.
- Version: 2.73.
- Purpose: Registers the VM as a session host in the AVD host pool using the registration token.
- Runs after AADLoginForWindows completes (dependency enforced).
- Configures the VM to join the host pool with Entra ID authentication enabled.

**Benefit:** Clean separation of concerns—Entra ID authentication is configured first, then AVD host pool registration follows. Deployment is reliable and works correctly on redeployment.

### Explicit Outbound Connectivity (March 2026 Compliance)

Starting March 31, 2026, Azure requires **explicit outbound connectivity methods** for new virtual networks. This template implements compliance through:

#### Implementation

**Standard Public IPs on NICs**
- Each session host VM gets a Standard Public IP address.
- Public IPs attached to VM network interfaces (not standalone).
- Provides explicit outbound NAT gateway.

**Service Endpoints (cost-free optimization)**
- Optimised routes to Azure services (Storage, Key Vault, Entra AD).
- Zero additional cost.
- Reduces data egress charges.

**Network Defaults**
- Subnets have `defaultOutboundAccess: false` (explicitly disabled).
- Forces all outbound traffic through Public IP (no hidden implicit access).

#### Public IP Lifecycle

- **Initial Deployment**: Bicep creates Standard Public IPs and associates them with VM NICs.
- **When Stopping VMs**: `Stop-AvdOccasional.ps1` deallocates VMs, then **deletes Public IPs** (saves ~£2–3/month per VM).
- **When Starting VMs**: `Start-AvdOccasional.ps1` creates **new Public IPs**, associates them with NICs, then starts VMs.
- **IP Address Changes**: Public IPs get new addresses each start cycle (acceptable and expected for outbound-only connectivity).

**Why This Approach:**
- ✅ **Compliant** – Meets Azure's explicit outbound requirement.
- ✅ **Cost-optimized** – £0/month when VMs stopped (vs ~£2–3/month if kept).
- ✅ **Secure** – NSG blocks ALL inbound traffic; IPs are outbound-only.
- ✅ **Automated** – Start/Stop scripts handle entire lifecycle.
- ✅ **Fully functional** – Provides internet access for updates, DSC downloads, browsing.

---

## Step-by-Step Deployment

### 1. Clone Repository

```powershell
git clone https://github.com/markheydon/avd-occasional.git
cd avd-occasional
```

### 2. Verify Tools

```powershell
# Check Azure CLI version
az --version

# Check Bicep CLI
az bicep version

# Check PowerShell version
$PSVersionTable.PSVersion

# Authenticate to Azure
az login

# Verify subscription
az account show  # Ensure correct subscription is selected
```

If you have multiple subscriptions, select the target one:

```powershell
az account set --subscription <subscription-id-or-name>
```

### 3. Customise Parameters

Edit `infra/parameters.json` to customize deployment:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "dev" },
    "workloadSize": { "value": "moderate" },
    "location": { "value": "ukwest" },
    "vmCount": { "value": 1 },
    "adminUsername": { "value": "avdadmin" },
    "tags": {
      "value": {
        "project": "avd-occasional",
        "managedBy": "bicep"
      }
    }
  }
}
```

**Common Customisations:**

**⚠️ Important**: Costs are estimates, in GBP, based on pricing information available publically in February 2026
and are subject to change by Microsoft at any time. You should use the official [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) to determine your potential costs before deployment.

| Parameter | Options | Default | Cost Impact |
|-----------|---------|---------|------------|
| `environment` | `dev`, `test`, `prod` | `dev` | None (affects naming) |
| `workloadSize` | `light`, `moderate` | `moderate` | **Light: £35/mo, Moderate: £100–120/mo** |
| `location` | Any Azure region | `ukwest` | Regional pricing variance |
| `vmCount` | `1`–`5` | `1` | **Each VM adds ~£100/mo active** |
| `adminUsername` | Any valid Windows name | `avdadmin` | None |

### 4. Prepare Admin Password

Create a secure password. **Never hardcode it in scripts or parameters.json.** Instead, prompt interactively:

```powershell
# Option 1: Interactive prompt (recommended)
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString

# Option 2: Generate random secure password (PowerShell 5.1+)
Add-Type -AssemblyName System.Web
$adminPassword = ConvertTo-SecureString ([System.Web.Security.Membership]::GeneratePassword(16, 3)) -AsPlainText -Force

# Option 3: Supply via environment variable (for CI/CD)
$adminPassword = ConvertTo-SecureString $env:AVD_ADMIN_PASSWORD -AsPlainText -Force
```

**Security note:** Passwords marked `@secure()` in Bicep are never logged to Azure activity logs.

### 5. Validate Template (Dry Run)

Test the deployment before creating resources:

```powershell
# Get admin password
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString

# Validate template
az deployment group validate `
  --resource-group avd-occasional-rg `
  --template-file infra/main.bicep `
  --parameters @infra/parameters.json `
  --parameters adminPassword=$adminPassword `
  -o json | ConvertFrom-Json
```

Or use the PowerShell script with `-WhatIf`:

```powershell
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword -WhatIf
```

Expected output: Lists resources to be created with no errors.

### 6. Create Resource Group

```powershell
az group create `
  --name avd-occasional-rg `
  --location ukwest
```

Alternatively, let the deployment script create it (steps below).

### 7. Deploy Infrastructure

```powershell
# Get admin password
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString

# Deploy (20–30 minutes for first deployment)
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword
```

**Expected duration:**
- Resource group creation: 1–2 minutes
- Template compilation: 1–2 minutes
- Infrastructure deployment: 15–20 minutes
- VM extensions (Entra ID join): 5–10 minutes
- **Total: 20–35 minutes**

Monitor progress in Azure Portal:
- Go to **Resource Groups** > `avd-occasional-rg` > **Deployments**
- Click latest deployment ("main") to view status

### 8. Verify Deployment

```powershell
# List all resources (should show ~15 resources)
az resource list --resource-group avd-occasional-rg -o table

# Check VM status (should show "running")
az vm list --resource-group avd-occasional-rg `
  --query "[].{Name:name, Status:powerState, VMSize:hardwareProfile.vmSize}" -o table

# View deployment outputs
az deployment group show --resource-group avd-occasional-rg `
  --name main `
  --query properties.outputs -o json
```

**Expected resources:**
- 1 Virtual Network
- 1 Network Security Group
- 1–5 VMs (depending on vmCount parameter)
- 1–5 Network Interfaces
- 1–5 OS Disks
- 1–5 Public IPs
- 1 Host Pool
- 1 Workspace
- 1 Application Group
- 1 System-assigned Managed Identity

### 9. Configure User Access (Required)

**⚠️ CRITICAL:** Users cannot connect without these role assignments. Allow 5–10 minutes for propagation after assignment.

Full instructions: [Quick Start: Step 3](quickstart.md#3-assign-role-permissions-required) or [Prerequisites: Role Assignment Requirements](prerequisites.md#role-assignment-requirements).

**Quick scripts:**

```powershell
# Role 1: Desktop Virtualization User
$appGroupId = (az resource list --resource-group avd-occasional-rg `
  --resource-type "Microsoft.DesktopVirtualization/applicationGroups" `
  --query '[0].id' -o tsv)

$userId = (az ad signed-in-user show --query id -o tsv)

az role assignment create `
  --role "Desktop Virtualization User" `
  --assignee $userId `
  --scope $appGroupId

# Role 2: Virtual Machine User Login
$vmIds = @(az vm list --resource-group avd-occasional-rg --query '[].id' -o tsv)
foreach ($vmId in $vmIds) {
    az role assignment create `
      --role "Virtual Machine User Login" `
      --assignee $userId `
      --scope $vmId
}
```

### 10. Test Connection

**Using Windows App (Recommended):**

1. Install [Windows App](https://apps.microsoft.com/detail/9n1f85v9t8bn) from Microsoft Store
2. Launch Windows App
3. Sign in with your Entra ID account
4. (First time) Subscribe to workspace: `avd-dev` (or custom name based on environment parameter)
5. Click **Personal Desktop**
6. Verify desktop is displayed

**Using Remote Desktop Connection (Advanced):**

RDP Shortpath requires additional setup (not recommended for occasional use). See [Azure Virtual Desktop RDP Properties](https://learn.microsoft.com/en-us/azure/virtual-desktop/configure-rdp-shortpath).

---

## Customising Deployment

### Add More Session Hosts (Scale Out)

```powershell
# Edit parameters.json
"vmCount": { "value": 3 }  # Changed from 1 to 3

# Redeploy (idempotent; only new VMs created)
$adminPassword = Read-Host "Enter admin password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword

# Assign roles to new VMs
$userId = (az ad signed-in-user show --query id -o tsv)
$vmIds = @(az vm list --resource-group avd-occasional-rg --query '[].id' -o tsv)
foreach ($vmId in $vmIds) {
    az role assignment create `
      --role "Virtual Machine User Login" `
      --assignee $userId `
      --scope $vmId
}
```

**Cost impact:** Each VM adds ~£100–120/month active, ~£0 deallocated.

### Switch Between Light and Moderate Workloads

```powershell
# Edit parameters.json
"workloadSize": { "value": "light" }  # From "moderate" to "light"

# Redeploy
$adminPassword = Read-Host "Enter admin password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword
```

**Cost impact:**
- Light (B2s): ~£35/month active
- Moderate (D2s_v3): ~£100–120/month active
- Deallocated: ~£0 (same for both)

**Note:** Existing VMs are replaced (not upgraded in-place). Redeploy may take longer as old VMs are removed first.

### Change Azure Region

```powershell
# Edit parameters.json
"location": { "value": "northeurope" }  # From "ukwest" to europe

# Redeploy
$adminPassword = Read-Host "Enter admin password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword
```

**Supported regions:**
- UK: `uksouth`, `ukwest`
- Europe: `northeurope`, `westeurope`
- Americas: `eastus`, `westus2`, `canadacentral`

See [Azure Virtual Desktop Supported Regions](https://learn.microsoft.com/en-us/azure/virtual-desktop/remote-desktop-supported-config).

### Use Custom Tags for Billing

```powershell
# Edit parameters.json
"tags": {
  "value": {
    "project": "avd-occasion",
    "team": "engineering",
    "cost-center": "1234",
    "environment": "dev"
  }
}

# Redeploy
$adminPassword = Read-Host "Enter admin password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword
```

Tags are used for cost analysis and resource filtering in Azure Cost Management.

---

## Troubleshooting Deployment

### General Debugging

```powershell
# Run with verbose output
$adminPassword = Read-Host "Enter password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword -Verbose

# Check latest deployment status
az deployment group show --resource-group avd-occasional-rg --name main -o json | ConvertFrom-Json | .properties
```

### Common Errors

See [Troubleshooting Guide: Deployment Issues](troubleshooting.md#deployment-issues) for:
- "Subscription does not have quota"
- "InvalidTemplateDeployment"
- "User does not have permissions"
- "Template contains invalid syntax"
- "Location not supported"

---

## Lifecycle Management

### Deallocate to Save Costs

```powershell
# Stop VMs and delete Public IPs (~98% cost savings)
.\scripts\Stop-AvdOccasional.ps1
```

Monthly cost drops from £94–126 to £2–3. Data and configuration preserved.

### Resume After Deallocate

```powershell
# Start VMs and recreate Public IPs (2–3 minute startup)
.\scripts\Start-AvdOccasional.ps1 -WaitForStartup
```

### Completely Delete Infrastructure

```powershell
# Permanently delete all resources (cannot be undone)
.\scripts\Remove-AvdOccasional.ps1 -Force
```

### Deploy Again After Deletion

```powershell
# Redeploy fresh infrastructure
$adminPassword = Read-Host "Enter admin password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword
```

---

## Cost Analysis

### Component Costs (UK Pricing, February 2026)

| Component | Deallocated | Active | Notes |
|-----------|-----------|--------|-------|
| **Session Host VM (D2s_v3, moderate)** | £0 | £90–120 | Largest cost driver |
| **Session Host VM (B2s, light)** | £0 | £30–40 | For lighter workloads |
| **OS Disk (Standard SSD)** | £2–3 | £2–3 | Always charged |
| **Standard Public IP** | £0 | £2–3 | Deleted when stopped |
| **VNet/NSG/Services** | £0 | £0 | Free (non-metered) |
| **TOTAL (moderate, 1 VM)** | **£2–3** | **£94–126** | **98% savings when deallocated** |

### Scaling Costs

| Configuration | Monthly Active | Monthly Deallocated | Use Case |
|---------------|----------------|------------------|----------|
| 1× Moderate | £94–126 | £2–3 | Single occasional user |
| 2× Moderate | £188–252 | £4–6 | Two occasional users |
| 3× Light | £90–120 | £6–9 | Three light workload users |
| 5× Moderate (max) | £470–630 | £10–15 | Five dedicated users |

### Cost Optimization Strategies

**Strategy 1: Deallocate after use (Recommended)**
- Deallocate VM to pause compute
- Preserves configuration and desktop state
- Quick resume (~2–3 min)
- Best for: Daily/weekly occasional use

**Strategy 2: Delete and redeploy (for infrequent use)**
- Complete infrastructure removal
- True zero cost between uses
- Longer recovery (~15–20 min)
- Best for: Monthly or less frequent use

**Strategy 3: Light workload**
- Switch from moderate (D2s_v3, £100–120/mo) to light (B2s, £35/mo)
- Requires 2–4 vCPU? Consider light
- Less RAM (4GB vs 8GB)
- Best for: Development, light document work

---

## Related Documentation

- [Quick Start](quickstart.md) – Get running in 5 minutes
- [Prerequisites](prerequisites.md) – Tools and environment setup
- [Architecture Overview](architecture.md) – How components interact
- [Troubleshooting](troubleshooting.md) – Common issues and solutions
- [Scripts Reference](scripts.md) – PowerShell commands explained

---

**Last Updated**: February 2026
