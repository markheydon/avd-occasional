# Azure Virtual Desktop (AVD) - Occasional Use Deployment

[![Bicep Lint](https://github.com/markheydon/avd-occasional/actions/workflows/bicep-lint.yml/badge.svg)](https://github.com/markheydon/avd-occasional/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bicep](https://img.shields.io/badge/IaC-Bicep-blue)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

Cost-effective Azure Virtual Desktop setup using Bicep Infrastructure as Code. Deploy and manage a personal desktop for occasional work sessions with minimal costs.

**⚠️ Important**: This template deploys **Entra ID (Azure AD) Joined VMs** for cloud-native scenarios. Session hosts authenticate via Entra ID. See [VM Authentication](#vm-authentication) below.

## Overview

This project provides a reproducible, parameterized approach to deploying Azure Virtual Desktop personal desktops for occasional, remote work scenarios. Focus is on **cost optimization** by deallocating (not deleting) VMs when not in use, reducing monthly costs from ~£92-125 to just £2-3.

**Typical cost profile:**
- **Idle (deallocated)**: ~£2-3/month (storage only).
- **Active (running)**: ~£92-125/month (compute + storage + public IP).
- **Completely deleted**: £0 (requires 10-15 min redeploy).

## Quick Start

### Prerequisites

- Azure CLI installed ([download](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)).
- Azure subscription with permissions to create resources.
- Bicep CLI (included with Azure CLI v2.20+).
- PowerShell 5.1+ (for deployment scripts).
- Entra ID (Azure AD) user account.
- **Admin credentials** for session host VMs (username & secure password).

### 1. Authenticate to Azure

```powershell
az login
# Select subscription if you have multiple
az account set --subscription <subscription-id>
```

### 2. Review Parameters

Edit `infra/parameters.json` to customize:
- `environment`: "dev" (for testing).
- `workloadSize`: "moderate" (or "light" for lighter workload).
- `location`: "ukwest" (or your preferred region).
- `vmCount`: 1 (number of session hosts).

### 3. Prepare Admin Credentials

The deployment requires admin credentials for the session host VMs. Create a secure password:

```powershell
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString
```

> **Security Note**: This password is used for local VM administration only and is not stored in parameters.json. It's required during deployment and should be a strong, unique password.

### 4. Deploy Infrastructure (Dry Run)

Test the deployment without creating resources:

```powershell
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword -WhatIf
```

### 5. Deploy (Create Resources)

```powershell
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword
```

Deployment takes ~15-20 minutes.

### 6. Verify Deployment

Check resources in Azure Portal or CLI:

```powershell
# List created resources
az resource list --resource-group avd-occasional-rg

# Check VM deployment status
az vm list-ip-addresses --resource-group avd-occasional-rg
```

### 7. Configure User Access

**In Azure Portal:**

1. Go to Resource Groups > `avd-occasional-rg`.
2. Find the Desktop Application Group (name: `avd-dev-dag-*`).
3. Click "Assignments".
4. Click "Add assignments".
5. Add your Entra ID user account.

### 8. Connect to Desktop

**Using Windows App (recommended):**

1. Install [Windows App](https://apps.microsoft.com/store/detail/windows-app/9MZQD45HFDX) from Microsoft Store.
2. Click "Subscribe" and sign in with Entra ID.
3. Select "Personal Desktop" workspace.
4. Launch your desktop.

**Using Remote Desktop Connection:**

Requires additional setup for RDP Shortpath (not recommended for occasional use).

---

## ⚠️ Important: Role Assignments Required

**This template does NOT automatically assign roles.** After deployment, you must manually configure **TWO separate role assignments** or users will not be able to connect to the AVD resources.

### Required Role Assignments

For Entra ID-joined AVD deployments, users need **two roles**:

1. **Desktop Virtualization User** - Grants access to the AVD workspace and application group.
2. **Virtual Machine User Login** - Allows login to the Entra ID-joined session host VMs.

### 1. Assign Desktop Virtualization User Role

This role allows users to see and access the AVD workspace:

**In Azure Portal:**

1. Navigate to Resource Groups > `avd-occasional-rg`.
2. Find the **Desktop Application Group**: `avd-dev-dag-*`.
3. Open the resource and go to **Access control (IAM)**.
4. Click **+ Add > Add role assignment**.
5. Select **Desktop Virtualization User** role.
6. Assign to your Entra ID user account(s).
7. Click **Save**.

**Via Azure CLI:**

```powershell
# Get Application Group ID
$appGroupId = (az resource list --resource-group avd-occasional-rg `
  --resource-type "Microsoft.DesktopVirtualization/applicationGroups" `
  --query '[0].id' -o tsv)

# Get user ID of the current user
$userId = (az ad signed-in-user show --query id -o tsv)

# Assign role
az role assignment create `
  --role "Desktop Virtualization User" `
  --assignee $userId `
  --scope $appGroupId
```

**Without this role assignment, users will not be able to:**
- See the workspace in Windows App.
- Connect to the personal desktop.
- Launch sessions.

### 2. Assign VM Login Role

This role allows users to actually log into the Entra ID-joined VM after connecting:

**In Azure Portal:**

1. Navigate to Resource Groups > `avd-occasional-rg`.
2. Find the **Virtual Machine(s)**: `avd-dev-vm-0-*`.
3. Open the VM and go to **Access control (IAM)**.
4. Click **+ Add > Add role assignment**.
5. Select **Virtual Machine User Login** role (or **Virtual Machine Administrator Login** for admin access).
6. Assign to your Entra ID user account(s).
7. Click **Save**.

**Via Azure CLI:**

```powershell
# Get your user ID
$userId = (az ad signed-in-user show --query id -o tsv)

# Get all VM resource IDs in the resource group (handles multiple VMs)
$vmIds = @(az vm list --resource-group avd-occasional-rg --query '[].id' -o tsv)

# Assign Virtual Machine User Login role to all VMs
foreach ($vmId in $vmIds) {
    az role assignment create `
      --role "Virtual Machine User Login" `
      --assignee $userId `
      --scope $vmId
}
```

**For administrator access instead:**
```powershell
# Get your user ID
$userId = (az ad signed-in-user show --query id -o tsv)

# Get all VM resource IDs in the resource group
$vmIds = @(az vm list --resource-group avd-occasional-rg --query '[].id' -o tsv)

# Assign Virtual Machine Administrator Login role to all VMs
foreach ($vmId in $vmIds) {
    az role assignment create `
      --role "Virtual Machine Administrator Login" `
      --assignee $userId `
      --scope $vmId
}
```

**Without this role assignment:**
- Users will see: "Your account is configured to prevent you from using this device".
- Login will fail even after successfully connecting to AVD.
- This is required for all Entra ID-joined VMs.

**Summary:** Allow 5-10 minutes after both role assignments for propagation before attempting to connect.

---

## VM Authentication

### Entra ID (Azure AD) Joined VMs

This template deploys **Entra ID (Azure AD) Joined session hosts**, which:
- ✅ Join VMs to your Entra ID tenant cloud-natively.
- ✅ Enable user sign-in with Entra ID credentials.
- ✅ Support passwordless authentication (Windows Hello, FIDO2).
- ✅ Integrate with cloud-based policies and compliance.

**This is ideal for:**
- Cloud-first organisations.
- Hybrid cloud workloads.
- Remote/occasional users.
- Organisations using Entra ID for identity.

---

## Project Structure

```
avd-occasional/
├── infra/
│   ├── main.bicep              # Main orchestration template
│   ├── parameters.json         # Deployment parameters
│   ├── modules/
│   │   ├── vnet.bicep          # Virtual Network and subnet
│   │   ├── nsg.bicep           # Network Security Group
│   │   ├── avd-pool.bicep      # Host Pool, Workspace, App Group
│   │   └── session-host.bicep  # Session Host VMs
├── scripts/
│   ├── Deploy-AvdOccasional.ps1     # Deploy infrastructure
│   ├── Start-AvdOccasional.ps1      # Start stopped VMs
│   ├── Stop-AvdOccasional.ps1       # Stop (pause) VMs
│   └── Remove-AvdOccasional.ps1     # Delete all resources
├── bicepconfig.json            # Bicep linter configuration
└── README.md                   # This file
```

---

## Why parameters.json Must Be a JSON File

You may notice `parameters.json` in the `/infra/` folder alongside Bicep files and wonder why parameters can't just be defined in a `.bicep` file. Here's why:

### Azure CLI Requirement

The Azure CLI `az deployment` command (used by `Deploy-AvdOccasional.ps1`) **only accepts `.json` parameter files**. It does not support `.bicep` or other formats:

```powershell
az deployment group create `
  --template-file main.bicep `
  --parameters @parameters.json  # ← Only .json accepted
```

### Parameter Layering

Parameters flow through multiple layers with clear precedence:

1. **Bicep defaults** (lowest priority): Default values in `param` declarations
2. **JSON file** (medium priority): `parameters.json` provides environment baseline.
3. **CLI overrides** (highest priority): Command-line `--parameters key=value` flags override both.

Example:
```powershell
# parameters.json says environment="dev"
# But CLI override wins:
--parameters environment=prod  # ← This takes precedence
```

This layering allows:
- **Reusable baselines** for different environments (parameters.dev.json, parameters.prod.json).
- **Safe parameter injection** without modifying files.
- **Flexible orchestration** from scripts or CI/CD pipelines.

### Separation of Concerns

The architecture intentionally separates:
- **Bicep files** = Infrastructure logic and definitions.
- **parameters.json** = Configuration defaults (version-controlled).
- **PowerShell scripts** = Orchestration and automation.

### Security: Why adminPassword Isn't in parameters.json

The `adminPassword` parameter is **intentionally excluded** from `parameters.json`:
- ✅ Never stored in Git.
- ✅ Prompted interactively during deployment.
- ✅ Passed securely via CLI at runtime.
- ✅ Marked `@secure()` in Bicep to prevent logging.

This follows infrastructure-as-code security best practices: **secrets are never committed to version control**.

---

## Workflow: Using Your Occasional Desktop

### Using the Desktop

1. **Start VMs** (if stopped):
   ```powershell
   .\scripts\Start-AvdOccasional.ps1
   ```
   Wait ~2-3 minutes for startup.

2. **Connect via Windows App**.
   - Launch Windows App.
   - Select workspace.
   - Launch "Personal Desktop".

3. **Work** - Use your desktop as normal.

### Saving Costs

3. **When done working, stop VMs**.
   ```powershell
   .\scripts\Stop-AvdOccasional.ps1
   ```
   This saves ~98% on compute costs while keeping everything ready for next use.

### If You Need to Scale Workload

**Switch from moderate to light:**

Edit `infra/parameters.json`:
```json
"workloadSize": {
  "value": "light"
}
```

Then redeploy:
```powershell
.\scripts\Deploy-AvdOccasional.ps1
```

**SKU Mappings:**
- `light`: Standard_B2s (2 vCPU, 4GB RAM) - ~£35/mo.
- `moderate`: Standard_D2s_v3 (2 vCPU, 8GB RAM) - ~£100/mo.

---

## Command Reference

### Deployment Commands

```powershell
# Create secure password
$adminPassword = Read-Host "Enter admin password" -AsSecureString

# Deploy with defaults (dev environment, moderate workload)
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword

# Deploy as test environment with light workload, 2 VMs
.\scripts\Deploy-AvdOccasional.ps1 -Environment test -WorkloadSize light -VmCount 2 -AdminPassword $adminPassword

# Dry-run (see what would be created)
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword -WhatIf

# Deploy with custom admin username
.\scripts\Deploy-AvdOccasional.ps1 -AdminUsername "myAdminUser" -AdminPassword $adminPassword
```

### VM Management Commands

```powershell
# Stop (pause) VMs to save on compute costs
.\scripts\Stop-AvdOccasional.ps1

# Start stopped VMs
.\scripts\Start-AvdOccasional.ps1
.\scripts\Start-AvdOccasional.ps1 -WaitForStartup  # Wait until fully started

# Check VM status
az vm list --resource-group avd-occasional-rg --query '[].{Name:name, PowerState:powerState}' -o table

# Get RDP connection info (if using RDP Shortpath)
az vm show -d --resource-group avd-occasional-rg --name <vm-name> --query publicIps -o tsv
```

### Resource Cleanup

```powershell
# Delete all resources (WARNING: cannot be undone)
.\scripts\Remove-AvdOccasional.ps1

# Delete without confirmation
.\scripts\Remove-AvdOccasional.ps1 -Force

# Delete using Azure CLI directly
az group delete --name avd-occasional-rg --yes
```

---

## Cost Analysis

_**⚠️ IMPORTANT NOTE**: The following cost analysis is based on UK pricing around February 2026 and should be used as an example only. Use the official [Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) for accurate estimates of your deployment costs._

### Component Cost Breakdown (Monthly)

| Component | Deallocated | Active | Notes |
|-----------|-----------|--------|-------|
| **D2s_v3 VM (moderate)** | £0 | £90-120 | Largest cost driver |
| **OS Disk (Standard SSD)** | £2-3 | £2-3 | Always charged, fast performance |
| **Standard Public IP** | £0 | £2-3 | Deleted when stopped (lifecycle managed) |
| **Network (VNet/NSG)** | £0 | £0 | Free |
| **Host Pool/Workspace** | £0 | £0 | Free (AVD service) |
| **App Group** | £0 | £0 | Free (management layer) |
| **TOTAL** | **£2-3** | **£94-126** | Deallocate = 98% savings |

**Public IP Lifecycle Management**: The Start/Stop scripts automatically manage Public IP lifecycle:
- **When stopped**: Public IPs are deleted to eliminate ~£2-3/month cost.
- **When started**: New Public IPs are created automatically.
- **IP addresses change** on each restart (acceptable for outbound-only connectivity).
- **Security**: NSG blocks ALL inbound traffic - IPs are for outbound internet only.

**VM Security & Performance Features**:
- **Trusted Launch**: Secure boot and vTPM enabled for enhanced security.
- **Standard SSD OS Disk**: Fast boot times and application performance (same cost as HDD).
- **Boot Diagnostics**: Enabled for troubleshooting (uses managed storage, no extra cost).
- **Automatic Windows Updates**: Managed by the platform to keep hosts patched.

### Cost Optimization Strategies

1. **Default: Deallocate after use** (Recommended).
   - Fast recovery (~3 min).
   - Minimal cost (~£2-3/mo).
   - Preserves desktop configuration.
   - Best for: Daily/weekly occasional use.

2. **Alternative: Delete and redeploy** (For very infrequent use)
   - True zero cost between uses
   - Longer recovery (~15 min)
   - Requires re-running `.\\scripts\\Deploy-AvdOccasional.ps1`
   - Best for: Monthly or less frequent use

3. **Adjust workload size**
   - Switch to "light" (B2s) to reduce active costs to ~£35/mo
   - Only need 2-4 vCPU? Use light workload
   - Need more power? Keep moderate

---

## Architecture

### Network Architecture

```
┌─────────────────────────────────────────┐
│  Azure Virtual Network (10.0.0.0/16)    │
├─────────────────────────────────────────┤
│  AVD Hosts Subnet (10.0.1.0/24)         │
│  (defaultOutboundAccess: false)         │
│  Service Endpoints (FREE):              │
│  • Microsoft.Storageoptimized routing): │
│  • Microsoft.Storage                    │
│  • Microsoft.KeyVault                   │
│  • Microsoft.AzureActiveDirectory       │
│  ┌──────────────────────────────┐       │
│  │ Session Host VM              │       │
│  │ ├─ Public IP (when running)  │       │
│  │ ├─ Network Interface (NIC)   │       │
│  │ ├─ OS Disk (30GB)            │       │
│  │ └─ System Managed Identity   │       │
│  └──────────────────────────────┘       │
│  NSG Rules:                             │
│  • Allow ALL outbound to Internet       │
│  • Allow Azure service tags outbound    │
│  • Deny ALL inbound from Internet       │
│                                         │
│  Outbound Connectivity:                 │
│  • Standard Public IP on NIC (explicit) │
│  • Deleted when VM stopped (cost opt.)  │
│  • Recreated when VM started         ───┘
         ↓ Reverse connection
┌──────────────────────────────────────────┐
│  Azure Virtual Desktop Service           │
│  (Manages sessions, no open ports)       │
└──────────────────────────────────────────┘
         ↓ User connects through
    Azure Virtual Desktop Clients
    (Windows App, Web, RDP)
```

### Resource Hierarchy

```
Resource Group (avd-occasional-rg)
├── Virtual Network
│   └── Subnet (avd-hosts with Service Endpoints)
├── Network Security Group
├── Host Pool (Personal, Direct assignment)
├── Workspace
├── Application Group (Desktop, linked to Workspace)
└── Session Host VMs (1-5)
    ├── Network Interfaces (private IPs only)
    └── OS Disks
    ├── Public IP Addresses (lifecycle managed
```

---

## Troubleshooting

### Deployment Fails with "Location Not Supported"

Some Azure regions don't support all resources. Supported regions for AVD:
- uksouth, ukwest (UK)
- northeurope, westeurope (Europe)
- eastus, westus2 (North America)
- canadacentral (Canada)

Change in `parameters.json`:
```json
"location": { "value": "northeurope" }
```

### Cannot Connect: "Workspace Not Available"

1. Check user is assigned to Desktop Application Group in Portal
2. Wait 5-10 minutes for role assignment to propagate
3. Sign out of Windows App and sign back in

### VMs Not Appearing in Deployment

Check deployment status:
```powershell
az deployment group list --resource-group avd-occasional-rg --query '[-1].[name, state, outputs]' -o table
```

View detailed error:
```powershell
az deployment group show --resource-group avd-occasional-rg --name <deployment-name>
```

### High Unexpected Costs

1. Check if VMs are still running (should deallocate after use)
2. Look for additional data egress charges
3. Verify resource cleanup after testing

Run:
```powershell
az vm list --resource-group avd-occasional-rg --query '[].{Name:name, PowerState:powerState, VmSize:hardwareProfile.vmSize}' -o table
```

---

## Security Considerations

✅ **Implemented:**
- No public IPs on VMs (reverse connections only)
- Network Security Group with minimal rules
- System-managed identities for Azure resources
- Entra ID user authentication required
- Encrypted OS disks (default)

⚠️ **Recommendations:**
- Use Azure Bastion if you need administrative access to VMs
- Enable Azure Defender for servers (additional cost)
- Review NSG rules quarterly
- Use role-based access control (RBAC) for resource group

---

## Updating/Modifying Deployment

### Add Another Session Host

Update `parameters.json`:
```json
"vmCount": { "value": 2 }
```

Redeploy:
```powershell
.\\scripts\\Deploy-AvdOccasional.ps1
```

### Change VM SKU

Update `parameters.json`:
```json
"workloadSize": { "value": "light" }
```

Note: Requires removing old VMs first:
```powershell
az vm delete --resource-group avd-occasional-rg --name <vm-name> --yes
```

---

## Deployment Idempotency & Design

This Bicep template implements **idempotent deployments**, which means:

- **Multiple deployments are safe**: Running the deployment script several times will only create/update the same set of resources, never duplicates
- **Stable resource names**: Resource names are deterministically generated from the resource group ID, ensuring consistent naming across deployments
- **No orphaned resources**: Failed or interrupted deployments don't leave behind randomly-named resources
- **Clean redeployments**: You can redeploy after fixing parameters without worrying about resource accumulation

### Technical Implementation

- **Session Host Extensions**: Both AVD Agent and BootLoader installation scripts are consolidated into a single `CustomScriptExtension` to comply with Azure's requirement of one CustomScript handler per VM
- **Naming**: Resource names derive from `uniqueString(resourceGroup().id)`, making them stable and idempotent

---

## FAQ

**Q: Can I use this for production workloads?**  
A: This template is designed for occasional, single-user scenarios. For production, consider:
- Pooled hosts (multiple users)
- Scaling and load balancing configuration
- High availability across availability zones
- Professional monitoring and alerting

**Q: Will I lose my desktop when I deallocate?**  
A: No. Deallocating preserves the entire VM, OS, and configuration. Only compute is stopped.

**Q: What if I delete the resource group by mistake?**  
A: Simply redeploy. The Bicep template is idempotent and records all configuration.

**Q: How long does startup/shutdown take?**  
A: Deallocate ~30 seconds, startup ~2-3 minutes. First connection to desktop ~30-60 seconds.

---

## Support & Feedback

For Azure Virtual Desktop documentation:
- [Azure Virtual Desktop Overview](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)

For Bicep documentation:
- [Learn Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

---

## License

This Bicep template is provided as-is for personal use. Azure services are subject to Microsoft's Terms of Service and pricing.

---

**Last Updated**: February 2026  
