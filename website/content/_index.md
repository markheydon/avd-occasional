---
title: Azure Virtual Desktop for Occasional Use
---

[![Bicep Lint](https://github.com/markheydon/avd-occasional/actions/workflows/bicep-lint.yml/badge.svg)](https://github.com/markheydon/avd-occasional/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bicep](https://img.shields.io/badge/IaC-Bicep-blue)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

Cost-effective **Azure Virtual Desktop** infrastructure for occasional work sessions. Deploy in minutes, deallocate to save 98% on costs, resume whenever needed.

## ⚡ Why This Project?

- **Personal desktop** – Purpose-built for individual occasional use.
- **Cost optimised** – £2–3/month idle, £94–126/month active (98% savings when deallocated).
- **Infrastructure as Code** – Reproducible, version-controlled Bicep templates.
- **Easy lifecycle** – Deploy once, deallocate/start as needed.
- **Cloud-native** – Entra ID-joined VMs, no on-premises AD required.

## 🚀 Quick Start (5 minutes)

```powershell
# 1. Clone and authenticate
git clone https://github.com/markheydon/avd-occasional.git
cd avd-occasional
az login

# 2. Deploy infrastructure (15–20 minutes)
.\scripts\Deploy-AvdOccasional.ps1

# 3. Assign role permissions (both required)
# See Quick Start Guide for detailed role assignment commands

# 4. Connect
# Use Windows App (Microsoft Store) to connect to your desktop

# Later: Save costs
.\scripts\Stop-AvdOccasional.ps1

# Resume when needed
.\scripts\Start-AvdOccasional.ps1
```

**Full instructions**: [Quick Start Guide](/docs/quickstart/)

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[Quick Start](/docs/quickstart/)** | Get up and running in ~25 minutes (includes 5–10 min role propagation). |
| **[Prerequisites](/docs/prerequisites/)** | Tools, Azure setup, role assignments, and security requirements. |
| **[Architecture Overview](/docs/architecture/)** | How components work together, cost drivers, security model. |
| **[Detailed Deployment](/docs/deployment-detailed/)** | Step-by-step walkthrough, customisation, and advanced options. |
| **[Troubleshooting](/docs/troubleshooting/)** | Common issues and solutions. |
| **[Scripts Reference](/docs/scripts/)** | PowerShell commands: Deploy, Start, Stop, Remove. |

## 💰 Cost Profile

**⚠️ Important**: Costs are estimates, in GBP, based on pricing information available publicly in July 2026
and are subject to change by Microsoft at any time. You should use the official [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) to determine your potential costs before deployment.

| State | Monthly Cost | Notes |
|-------|-------------|-------|
| **Deallocated** | £2–3 | VMs stopped, disks retained (instant resume) |
| **Running** | £94–126 | Full D2s_v5 compute (1 VM, moderate workload) |
| **Deleted** | £0 | Complete removal (15–20 min redeploy) |
| **Savings** | **~98%** | Cost reduction when deallocated vs running |

**Component breakdown:**
- Session Host VM: £90–120/month (active) → £0 (deallocated).
- Public IP: £2–3/month (active) → £0 (deallocated & deleted).
- OS Disk: £2–3/month (always charged).

See [Detailed Deployment: Cost Analysis](/docs/deployment-detailed/#cost-analysis) for scaling costs and optimisation strategies.

## 🏗️ Architecture at a Glance

See the [Architecture Overview](/docs/architecture/#high-level-architecture) for the full diagram and component descriptions.

**Key features:**
- Entra ID-joined VMs (cloud-native, no VPN required).
- No inbound public ports (reverse connection only).
- Public IPs deleted when VMs stopped (cost optimisation).
- Service Endpoints for optimised Azure service routing.
- Fully idempotent deployment.

## 🎯 Use Cases

✅ **Remote work from alternate location** – Coffee shop, co-working, travel.
✅ **Temporary compute needs** – Project work, testing, demos.
✅ **Cost-sensitive scenarios** – Deallocate between sessions.
✅ **Personal productivity** – Persistent desktop, cloud-native identity.

❌ **Not for:** Pooled multi-user scenarios.
❌ **Not for:** Always-on production workloads.

## 🔧 Key Features

- ✅ **Bicep Infrastructure as Code** – Reproducible, auditable, version-controlled.
- ✅ **Parameterised configuration** – Switch workload size (light/moderate) in one parameter.
- ✅ **Personal desktop** – Single user, persistent configuration.
- ✅ **Entra ID authentication** – Cloud-native identity, supports passwordless auth.
- ✅ **Deallocate pattern** – Stop VMs to save costs, resume in 2–3 minutes.
- ✅ **Automated lifecycle scripts** – Deploy, start, deallocate, cleanup.
- ✅ **Minimal security** – Reverse connections, NSG included, no RDP ports.
- ✅ **UK-friendly defaults** – Region: `ukwest`, pricing in GBP _(Regionalising of VMs not yet available see #2)_.

## 📋 Prerequisites at a Glance

| Requirement | Status | Details |
|-------------|--------|---------|
| **Azure CLI** | Required | v2.40+ ([Install](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)) |
| **Bicep CLI** | Required | Included with Azure CLI 2.20+ |
| **PowerShell** | Required | 5.1+ ([Install](https://aka.ms/PSWindows)) |
| **Git** | Required | Clone repository ([Download](https://git-scm.com)) |
| **Azure subscription** | Required | Contributor or Owner role |
| **Entra ID tenant** | Required | Usually available with Microsoft 365 |

For full prerequisite details, see [Prerequisites Guide](/docs/prerequisites/).

## 📘 Documentation & Resources

### Getting Started

1. **New to this project?** Start with [Quick Start](/docs/quickstart/).
2. **Need environment setup?** See [Prerequisites](/docs/prerequisites/).
3. **Want to understand how it works?** Read [Architecture Overview](/docs/architecture/).
4. **Detailed walkthrough?** Follow [Detailed Deployment Guide](/docs/deployment-detailed/).
5. **Troubleshooting?** Check [Troubleshooting Guide](/docs/troubleshooting/).
6. **Using PowerShell scripts?** See [Scripts Reference](/docs/scripts/).

### External Resources

- [Azure Virtual Desktop Documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [Azure Virtual Desktop Learn Path](https://learn.microsoft.com/en-us/training/paths/deploy-manage-azure-virtual-desktop/)
- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure CLI Reference](https://learn.microsoft.com/en-us/cli/azure/)
- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)

### Project Documentation

- [CONTRIBUTING](https://github.com/markheydon/avd-occasional/blob/main/CONTRIBUTING.md) – Contribution guidelines
- [CHANGELOG](https://github.com/markheydon/avd-occasional/blob/main/CHANGELOG.md) – Version history and release notes
- [LICENSE](https://github.com/markheydon/avd-occasional/blob/main/LICENSE) – MIT License
- [README](https://github.com/markheydon/avd-occasional/blob/main/README.md) – Project overview

### GitHub

- [Repository](https://github.com/markheydon/avd-occasional) – Source code and issue tracking
- [Issues](https://github.com/markheydon/avd-occasional/issues) – Report bugs or request features
- [Discussions](https://github.com/markheydon/avd-occasional/discussions) – Questions and ideas

---

**Last Updated**: July 2026  