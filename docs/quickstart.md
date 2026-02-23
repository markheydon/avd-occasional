---
layout: default
title: Quick Start
---

# Quick Start

Get your Azure Virtual Desktop environment running in approximately 5 minutes.

## Prerequisites Checklist

Before starting, ensure you have:

- ✅ Azure CLI v2.40+ installed.
- ✅ Bicep CLI (included with Azure CLI v2.20+).
- ✅ PowerShell 5.1+.
- ✅ Azure subscription with Contributor role.
- ✅ Entra ID user account.
- ✅ Strong admin password for session hosts.

For detailed prerequisites, see [Prerequisites Guide](prerequisites.md).

## 1. Clone and Authenticate

```powershell
git clone https://github.com/markheydon/avd-occasional.git
cd avd-occasional
az login
az account show  # Verify correct subscription
```

## 2. Deploy Infrastructure (15-20 minutes)

```powershell
# When prompted, enter a strong admin password for the session host VMs
.\scripts\Deploy-AvdOccasional.ps1
```

This creates all Azure Virtual Desktop resources: virtual network, host pool, session hosts, and more.

## 3. Assign Role Permissions (Required)

**⚠️ Users cannot connect without these role assignments.**

### Role 1: Desktop Virtualization User (Application Group)

```powershell
$appGroupId = (az resource list --resource-group avd-occasional-rg `
  --resource-type "Microsoft.DesktopVirtualization/applicationGroups" `
  --query '[0].id' -o tsv)

$userId = (az ad signed-in-user show --query id -o tsv)

az role assignment create `
  --role "Desktop Virtualization User" `
  --assignee $userId `
  --scope $appGroupId
```

### Role 2: Virtual Machine User Login (Session Host VMs)

```powershell
$userId = (az ad signed-in-user show --query id -o tsv)
$vmIds = @(az vm list --resource-group avd-occasional-rg --query '[].id' -o tsv)

foreach ($vmId in $vmIds) {
    az role assignment create `
      --role "Virtual Machine User Login" `
      --assignee $userId `
      --scope $vmId
}
```

**Allow 5–10 minutes for roles to propagate before connecting.**

## 4. Connect to Your Desktop

1. Install [Windows App](https://apps.microsoft.com/store/detail/windows-app/9MZQD45HFDX) from Microsoft Store.
2. Open Windows App and sign in with your Entra ID account.
3. Select the "Personal Desktop" workspace.
4. Launch your desktop.

You're now connected and can start working!

## Next Steps

### Save Costs Between Sessions

When finished working, deallocate VMs to save ~98% on compute costs:

```powershell
.\scripts\Stop-AvdOccasional.ps1
```

Restart whenever you need the desktop:

```powershell
.\scripts\Start-AvdOccasional.ps1
```

### Explore Further

- [Architecture Overview](architecture.md) – Understand the infrastructure.
- [Full Deployment Guide](deployment-detailed.md) – Detailed walkthrough and customisation.
- [Troubleshooting](troubleshooting.md) – Common issues and solutions.
- [PowerShell Scripts Reference](scripts.md) – Available commands and options.

### Issues?

See [Troubleshooting Guide](troubleshooting.md) for common problems and solutions.

---

**Estimated time to first connection**: 25–30 minutes (15–20 min deployment + 5–10 min role propagation).
