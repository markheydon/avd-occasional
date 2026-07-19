# Azure Virtual Desktop for Occasional Use

[![Bicep Lint](https://github.com/markheydon/avd-occasional/actions/workflows/bicep-lint.yml/badge.svg)](https://github.com/markheydon/avd-occasional/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bicep](https://img.shields.io/badge/IaC-Bicep-blue)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

Cost-effective **Azure Virtual Desktop** infrastructure for occasional remote work. Deploy to Azure in 15–20 minutes, deallocate to save 98% on costs, resume whenever needed.

**⚠️ Important**: This template deploys **Entra ID-joined VMs** (cloud-native, no on-premises AD required). All communication is via secure reverse connections—no RDP ports exposed.

## Documentation

For full documentation, guides, and troubleshooting, visit the [documentation site](https://markheydon.github.io/avd-occasional).

To preview docs locally (requires Docker or Podman): `.\scripts\Invoke-HugoSite.ps1 serve`

## Key Features

- ✅ **Bicep Infrastructure as Code** – Reproducible, auditable, version-controlled.
- ✅ **Cost optimised** – 98% savings when deallocated.
- ✅ **Entra ID-joined VMs** – Cloud-native, no on-premises AD required.
- ✅ **Fully idempotent** – Safe to redeploy multiple times.
- ✅ **Automated lifecycle scripts** – Deploy, start, stop, remove.
- ✅ **Zero inbound access** – Reverse connections only, NSG included.

---

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
```

### 2. Review Parameters

Edit `infra/parameters.json` to customise:
- `environment`: "dev" (for testing).
- `workloadSize`: "moderate" (or "light" for lighter workload).
- `location`: "ukwest" (or your preferred region).
- `vmCount`: 1 (number of session hosts).

### 3. Prepare Admin Credentials

The deployment requires admin credentials for the session host VMs. Create a secure password:

```powershell
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString
```

_**Security Note**: This password is used for local VM administration only and is not stored in parameters.json. It's required during deployment and should be a strong, unique password._

### 4. Deploy Infrastructure (Dry Run)

Test the deployment without creating resources:

```powershell
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword -WhatIf
```

### 5. Deploy (Create Resources)

```powershell
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

### 7. Assign Required Roles

Assign the required roles to your Entra ID user for VM login and AVD access. You need **Desktop Virtualization User** on the application group, plus **one** VM sign-in role on each session host:

- **Virtual Machine User Login** – Standard user (default).
- **Virtual Machine Administrator Login** – Local admin while signed in with Entra ID (for developers).

See [Quick Start: Step 3](https://markheydon.github.io/avd-occasional/docs/quickstart/#3-assign-role-permissions-required) for full commands, including the optional administrator role.

```powershell
# Get current user
$userId = (az ad signed-in-user show --query id -o tsv)

# Desktop Virtualization User role assignment
$appGroupId = (az resource list --resource-group avd-occasional-rg `
  --resource-type "Microsoft.DesktopVirtualization/applicationGroups" `
  --query '[0].id' -o tsv)
az role assignment create `
  --role "Desktop Virtualization User" `
  --assignee $userId `
  --scope $appGroupId

# Virtual Machine User Login role assignment (use Administrator Login instead for dev/admin access)
$vmIds = @(az vm list --resource-group avd-occasional-rg --query '[].id' -o tsv)
foreach ($vmId in $vmIds) {
    az role assignment create `
      --role "Virtual Machine User Login" `
      --assignee $userId `
      --scope $vmId
}
```

The `avdadmin` password from deployment is for the separate local break-glass account, not for elevating your Entra ID user.

---

## Estimated Cost at a Glance

**⚠️ Important**: Costs are estimates, in GBP, based on pricing information available publicly in July 2026 and are subject to change by Microsoft at any time. You should use the official [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) to determine your potential costs before deployment.

| State | Monthly Cost | When To Use |
|-------|-------------|-----------|
| Running | £94–126 | During work sessions |
| Deallocated | £2–3 | Between sessions (instant resume) |
| Deleted | £0 | Complete cleanup (15–20 min redeploy) |

**Bottom line:** Deallocate when done = 98% cost savings. Resume in 2–3 minutes.

---

## For Contributors

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing improvements. See [AGENTS.md](AGENTS.md) for conventions used by coding agents.

## License

MIT License – See [LICENSE](LICENSE) for details.

---

**Last Updated**: July 2026  
