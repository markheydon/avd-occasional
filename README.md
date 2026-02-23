# Azure Virtual Desktop for Occasional Use

[![Bicep Lint](https://github.com/markheydon/avd-occasional/actions/workflows/bicep-lint.yml/badge.svg)](https://github.com/markheydon/avd-occasional/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bicep](https://img.shields.io/badge/IaC-Bicep-blue)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

Cost-effective **Azure Virtual Desktop** infrastructure for occasional remote work. Deploy to Azure in 15–20 minutes, deallocate to save 98% on costs, resume whenever needed.

**⚠️ Important**: This template deploys **Entra ID-joined VMs** (cloud-native, no on-premises AD required). All communication is via secure reverse connections—no RDP ports exposed.

## Quick Links

| What You Want to Do | Go To |
|-------------------|-------|
| **Get running in 5 minutes** | [Quick Start Guide](docs/quickstart.md) |
| **Understand prerequisites** | [Prerequisites Guide](docs/prerequisites.md) |
| **Learn how it works** | [Architecture Overview](docs/architecture.md) |
| **Detailed deployment steps** | [Detailed Deployment Guide](docs/deployment-detailed.md) |
| **Fix an issue** | [Troubleshooting Guide](docs/troubleshooting.md) |
| **Use PowerShell scripts** | [Scripts Reference](docs/scripts.md) |
| **Full web documentation** | [GitHub Pages Docs](https://markheydon.github.io/avd-occasional) |

## Cost at a Glance

| State | Monthly Cost | When To Use |
|-------|-------------|-----------|
| Running | £94–126 | During work sessions |
| Deallocated | £2–3 | Between sessions (instant resume) |
| Deleted | £0 | Complete cleanup (15–20 min redeploy) |

**Bottom line:** Deallocate when done = 98% cost savings. Resume in 2–3 minutes.

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

---

## Key Features

- ✅ **Bicep Infrastructure as Code** – Reproducible, auditable, version-controlled
- ✅ **Cost optimised** – 98% savings when deallocated
- ✅ **Entra ID-joined VMs** – Cloud-native, no on-premises AD required
- ✅ **Fully idempotent** – Safe to redeploy multiple times
- ✅ **Automated lifecycle scripts** – Deploy, start, stop, remove
- ✅ **Zero inbound access** – Reverse connections only, NSG included
- ✅ **March 2026 compliant** – Explicit outbound connectivity via Standard Public IPs

## For Contributors

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on contributing improvements.

## License

MIT License – See [LICENSE](LICENSE) for details.

---

**Last Updated**: February 2026  
