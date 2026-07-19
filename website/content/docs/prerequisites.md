---
title: Prerequisites
weight: 10
---

Before deploying Azure Virtual Desktop, ensure your environment is properly configured.

## System Requirements

### Locally Installed Tools

| Tool | Version | Purpose | Download |
|------|---------|---------|----------|
| Azure CLI | 2.40+ | Azure resource management | [Install Guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Bicep CLI | 0.20+ | Infrastructure-as-code compilation | Included with Azure CLI 2.20+ |
| PowerShell | 5.1+ | Deployment orchestration | [Install Guide](https://aka.ms/PSWindows) |
| Git | Any version | Repository cloning | [Download](https://git-scm.com) |

### Verification

Check installed versions:

```powershell
# Check Azure CLI
az --version

# Check Bicep CLI
az bicep version

# Check PowerShell
$PSVersionTable.PSVersion

# Check Git
git --version
```

## Azure Prerequisites

### Azure Subscription

- ✅ Active Azure subscription.
- ✅ **Contributor** or **Owner** role on the subscription.
- ✅ Quota available for virtual machines in your chosen region.

To verify your role:

```powershell
az role assignment list --assignee (az account show --query user.name -o tsv) --query '[].roleDefinitionName' -o tsv
```

### Entra ID (Azure AD)

- ✅ Entra ID tenant access (usually available to organisations using Microsoft 365).
- ✅ User account in the Entra ID tenant.
- ✅ Ability to create role assignments (typically available to Global Admins or subscription Owners).

To verify Entra ID access:

```powershell
az ad signed-in-user show
```

### Azure Region

Deploy in a region that supports all required services:

**Supported UK regions:**
- `uksouth`.
- `ukwest` (default in this template).

**Other popular regions:**
- `northeurope`.
- `westeurope`.
- `eastus`.
- `westus2`.
- `canadacentral`.

## Security & Credentials

### Admin Credentials

The deployment requires a strong admin password for session host VMs:

| Requirement | Details |
|-------------|---------|
| Username | Alphanumeric, can contain `.`, `-`, `_` (not allowed: spaces, special chars). |
| Default username | `avdadmin` (configurable). |
| Password | **Must be strong**: 8+ chars, mixed case, numbers, special chars. |
| Storage | **Never stored in `parameters.json`** – prompted at deployment time. |
| Encryption | Marked `@secure()` in Bicep; not logged in Azure activity. |

### Generate Secure Password (PowerShell)

```powershell
# Interactive prompt (recommended)
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString
```

### Entra ID Authentication

This deployment uses **Entra ID-joined VMs**, which means:

- ✅ VMs authenticate using cloud-based Entra ID identity (no on-premises AD required)
- ✅ Users sign in with Entra ID credentials (same as Microsoft 365)
- ✅ Supports modern authentication (passwordless, Windows Hello, FIDO2)
- ✅ Automatic Windows Updates and cloud policies

**What this enables:**
- Remote workers can connect without VPN
- No hybrid identity synchronisation required
- Cloud-native security policies apply to VMs

## Role Assignment Requirements

### Why Two Roles Are Required

After deployment, users need **two separate role assignments** to connect:

1. **Desktop Virtualization User** – Access the AVD workspace and application group.
2. **VM sign-in role** – Log into the Entra ID-joined session host VMs. Assign **one** of:
   - **Virtual Machine User Login** – Standard user sign-in (default, least privilege).
   - **Virtual Machine Administrator Login** – Sign in with local administrator rights (for developers who need to install software or change system settings).

You do not need both VM sign-in roles. Choose User Login for occasional use, or Administrator Login if you need admin rights while signed in with your Entra ID account.

Without the AVD role and a VM sign-in role, users will receive:
- "Workspace not available" in Windows App, or
- "Your account is configured to prevent you from using this device" when trying to log in.

The `avdadmin` local account created during deployment is separate from Entra ID sign-in. It provides a break-glass administrator account but requires signing in with that username and password, not your Entra credentials.

### Assigning Roles

See [Quick Start: Step 3](/docs/quickstart/#3-assign-role-permissions-required) for automated commands, or follow the manual steps below.

Role assignments are manual post-deploy steps today. Automating them via Bicep is tracked in [issue #3](https://github.com/markheydon/avd-occasional/issues/3).

#### Manual Assignment via Azure Portal

**For Desktop Virtualization User role:**

1. Open Azure Portal
2. Go to **Resource Groups** > `avd-occasional-rg`
3. Find the **Desktop Application Group** (name: `avd-dev-dag-*`)
4. Click the resource name to open it
5. Go to **Access control (IAM)** tab
6. Click **+ Add** > **Add role assignment**
7. Search for and select **Desktop Virtualization User**
8. Click **Next**
9. Select **User, group, or service principal**
10. Click **+ Select members**
11. Search for your Entra ID user account
12. Click your account to select it
13. Click **Select** > **Next** > **Review + assign**

**For VM sign-in role** (choose one per VM):

1. Repeat the steps above, but:
   - Find each **Session Host VM** (name: `avd-dev-vm-0-*`, etc.)
   - Select role **Virtual Machine User Login** (standard user) or **Virtual Machine Administrator Login** (local admin)
   - Assign to the same user account

**Allow 5–10 minutes for role propagation** before attempting to connect.

#### Role Assignment via Azure CLI

**Desktop Virtualization User role:**

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

**Virtual Machine User Login role** (standard user, for all VMs):

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

**Virtual Machine Administrator Login role** (local admin, for all VMs):

```powershell
$userId = (az ad signed-in-user show --query id -o tsv)

$vmIds = @(az vm list --resource-group avd-occasional-rg --query '[].id' -o tsv)

foreach ($vmId in $vmIds) {
    az role assignment create `
      --role "Virtual Machine Administrator Login" `
      --assignee $userId `
      --scope $vmId
}
```

See [Quick Start: Role 2](/docs/quickstart/#role-2-vm-sign-in-session-host-vms) for guidance on choosing between these roles.

### Assigning Roles to Multiple Users

To add other users or your entire team, repeat the role assignment steps for each user.

For large-scale deployments, consider:
- Assigning roles to Entra ID groups instead of individual users
- Using [Azure Lighthouse](https://learn.microsoft.com/en-us/azure/lighthouse/) for delegated access

## Connectivity

### Outbound Internet Access

The deployment requires outbound internet access for:
- Windows Updates
- Azure Virtual Desktop agent downloads
- DSC script downloads
- SSL certificate validation

The VMs' Network Security Group allows all outbound traffic by default.

### Inbound Access

**No inbound ports are required.** Azure Virtual Desktop uses reverse connections from the VM to the Azure Virtual Desktop service. Users connect through:
- Windows App
- Web browser (Azure Virtual Desktop web client)
- Remote Desktop Protocol (RDP) clients

## Post-Deployment Verification

After reviewing prerequisites, you're ready to deploy. Start with the [Quick Start Guide](/docs/quickstart/).

---

**Next**: [Quick Start Guide](/docs/quickstart/)

---

**Last Updated**: July 2026