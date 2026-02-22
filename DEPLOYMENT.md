# Detailed Deployment Guide

> **Advanced users**: See [README.md](./README.md) for quick start.

## Important Prerequisites

⚠️ **This template deploys Entra ID (Azure AD) Joined session hosts.** VMs authenticate via cloud-based Entra ID. See [README: VM Authentication](./README.md#vm-authentication) for details.

⚠️ **Role assignments are NOT automatic.** After deployment, you must manually assign the "Desktop Virtualization User" role to users. See [README: Role Assignments Required](./README.md#-important-role-assignments-required) for step-by-step instructions.

## Prerequisites Checklist

- [ ] Azure CLI v2.40+ (`az --version`)
- [ ] Bicep v0.20+ (`az bicep version`)
- [ ] PowerShell 5.1+ (`$PSVersionTable.PSVersion`)
- [ ] Azure subscription with **"Owner" or "Contributor"** role
- [ ] Entra ID tenant access
- [ ] **Admin username and secure password** for session host VMs

## Deployment Architecture

### Idempotent Design

This template is designed for **safe, repeatable deployments**:

- **Resource Naming**: Names are deterministically derived from the resource group ID using `uniqueString(resourceGroup().id)`.
- **No Duplicates on Rerun**: Multiple deployments create/update the same resources without accumulating duplicates.
- **Failed Deployment Recovery**: If a deployment fails midway, simply rerun - only missing resources will be created.

### Session Host Extension Architecture

The deployment combines AVD Agent and BootLoader installation into a **single `CustomScriptExtension`** for each VM:

- **Why**: Azure Windows VMs support only one CustomScript handler per VM. Attempting multiple CustomScriptExtensions with the same handler causes `BadRequest` errors.
- **How**: Both installation scripts run sequentially within a single extension execution.
- **Benefit**: Reliable, conflict-free deployment that works correctly on redeployment.

## Step-by-Step Deployment

### 1. Clone & Setup

```powershell
git clone https://github.com/markheydon/avd-occasional.git
cd avd-occasional
```

### 2. Verify Azure CLI

```powershell
az --version
az bicep version
az login
az account show  # Verify subscription
```

### 3. Customize Parameters

Edit `infra/parameters.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environment": { "value": "dev" },
    "workloadSize": { "value": "moderate" },
    "location": { "value": "ukwest" },
    "vmCount": { "value": 1 },
    "adminUsername": { "value": "avdadmin" }
  }
}
```

> **Note**: `adminPassword` is NOT included in parameters.json for security. It will be provided via deployment script parameter or Azure CLI.

### 3b. Prepare Admin Password

Create a secure password for deployment. You'll pass this when creating resources:

```powershell
# Option 1: Prompt for password (recommended)
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString

# Option 2: Store in variable (for scripts)
$adminPassword = ConvertTo-SecureString 'YourSecurePassword123!' -AsPlainText -Force
```

> **Security Best Practice**: Never hardcode passwords in scripts or parameters files. The password should be managed securely (e.g., from Azure Key Vault, environment variables, or prompted interactively).

### 4. Test Deployment (Dry Run)

```powershell
# Get admin password
$adminPassword = Read-Host "Enter admin password for session hosts" -AsSecureString

# Dry-run the deployment
.\\scripts\\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword -WhatIf
```

Review output—should show resources to be created with no errors.

### 5. Create Resource Group

```powershell
az group create `
  --name avd-occasional-rg `
  --location ukwest
```

### 7. Deploy Infrastructure

```powershell
.\scripts\Deploy-AvdOccasional.ps1
```

**Expected duration**: 15-20 minutes

Monitor progress in Azure Portal > Resource Groups > avd-occasional-rg > Deployments

### 8. Verify Deployment

```powershell
# List all resources
az resource list --resource-group avd-occasional-rg -o table

# Check VM status
az vm list --resource-group avd-occasional-rg `
  --query '[].{Name:name, Status:powerState}' -o table

# View deployment outputs
az deployment group show --resource-group avd-occasional-rg `
  --name main `
  --query properties.outputs
```

### 9. Configure User Access (Required)

**⚠️ IMPORTANT: This step is required for users to access the desktop.**

Without role assignments, users will see "No workspaces available" in Windows App even though the infrastructure is deployed.

**Option 1: Azure Portal (Recommended)**

1. Navigate to Resource Groups > avd-occasional-rg.
2. Find Application Group: `avd-dev-dag-*`.
3. Go to **Access control (IAM)** tab.
4. Click **+ Add > Add role assignment**.
5. Select **Desktop Virtualization User** role.
6. Assign to your Entra ID user account(s).
7. Click **Save**.

**Option 2: Azure CLI**

```powershell
# Get Application Group ID
$appGroupId = (az resource list --resource-group avd-occasional-rg `
  --resource-type "Microsoft.DesktopVirtualization/applicationGroups" `
  --query '[0].id' -o tsv)

# Get user ID
$userId = (az ad user show --id "user@example.com" --query id -o tsv)

# Assign role
az role assignment create `
  --role "Desktop Virtualization User" `
  --assignee $userId `
  --scope $appGroupId
```

**Wait 5-10 minutes** for role propagation before testing connections.

### 10. Test Connection

**Using Windows App:**

1. Install from [Microsoft Store](https://apps.microsoft.com/store/detail/windows-app/9MZQD45HFDX).
2. Sign in with Entra ID credentials.
3. Subscribe to workspace.
4. Launch "Personal Desktop".

## Troubleshooting Deployment Errors

### Error: "The subscription does not have quota"

Some regions have resource quotas. Try a different region or request quota increase:

```powershell
az provider show --namespace Microsoft.Compute --query "resourceTypes[?resourceType=='virtualMachines'].locations" -o table
```

### Error: "InvalidTemplateDeployment"

Run validation:
```powershell
az deployment group validate `
  --resource-group avd-occasional-rg `
  --template-file infra/main.bicep `
  --parameters @infra/parameters.json
```

Check detailed error message and Bicep lint output.

### Error: "User does not have permissions"

Ensure your Azure account has **Contributor** role:
```powershell
az role assignment list --assignee (az account show --query user.name -o tsv)
```

## Post-Deployment Checklist

- [ ] Resource group created in Azure Portal
- [ ] All resources visible (VNet, NSG, Host Pool, VMs)
- [ ] VMs powered on and running
- [ ] User assigned to Desktop Application Group role
- [ ] Windows App shows workspace available
- [ ] Can connect and see desktop

## VM Authentication: Entra ID Joined

This deployment uses **Entra ID (Azure AD) Joined** session hosts for cloud-native AVD deployments.

### What This Means

- ✅ VMs are joined to your **Entra ID tenant** (cloud-based identity).
- ✅ Users sign in with **Entra ID credentials** (same as Microsoft 365).
- ✅ Supports modern authentication (passwordless, Windows Hello, FIDO2).
- ✅ Works seamlessly for remote-first and cloud-first organisations.

## Scaling

### Add Another Session Host

```json
// infra/parameters.json
"vmCount": { "value": 2 }
```

Redeploy: `.\\scripts\\Deploy-AvdOccasional.ps1`

### Switch to Light Workload

```json
"workloadSize": { "value": "light" }
```

### Change Region

```json
"location": { "value": "northeurope" }
```

## Clean Up

**Keep infrastructure, stop VMs (90% cost savings):**
```powershell
.\\scripts\\Stop-AvdOccasional.ps1
```

**Delete everything:**
```powershell
.\\scripts\\Remove-AvdOccasional.ps1
```

---

**See Also**: [README.md](./README.md) for quick start and [Cost Analysis section](./README.md#cost-analysis).