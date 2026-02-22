---
layout: default
title: AVD Occasional
---

# Azure Virtual Desktop - Occasional Use

[![Bicep Lint](https://github.com/markheydon/avd-occasional/actions/workflows/bicep-lint.yml/badge.svg)](https://github.com/markheydon/avd-occasional/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bicep](https://img.shields.io/badge/IaC-Bicep-blue)](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

Cost-effective **Azure Virtual Desktop** infrastructure for occasional work sessions. Deploy in minutes, deallocate to save 90% on costs, resume whenever needed.

## ⚡ Why This Project?

- **Personal desktop** purpose-built for individual occasional use.
- **Cost optimized** - £10-15/month idle vs £100-120/month active.
- **Infrastructure as Code** - Reproducible, version-controlled Bicep templates.
- **Easy lifecycle** - Deploy once, deallocate/start as needed.
- **Production ready** - Best practices, security, monitoring included.

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[Quick Start](../README.md#quick-start)** | Get up and running in 5 minutes. |
| **[Full README](../README.md)** | Complete overview and reference. |
| **[Deployment Guide](../DEPLOYMENT.md)** | Detailed step-by-step walkthrough. |
| **[Contributing](../CONTRIBUTING.md)** | How to contribute improvements. |
| **[Changelog](../CHANGELOG.md)** | Version history and updates. |

## 🚀 Quick Start

```powershell
# Clone
git clone https://github.com/markheydon/avd-occasional.git
cd avd-occasional

# Authenticate
az login

# Deploy (15-20 min)
.\scripts\Deploy-AvdOccasional.ps1

# Later: Save 90% on costs
.\scripts\Stop-AvdOccasional.ps1

# Resume when needed
.\scripts\Start-AvdOccasional.ps1
```

## 💰 Cost Profile

| State | Monthly Cost | Notes |
|-------|-------------|-------|
| **Deallocated** | £10-15 | Storage only, VMs paused. |
| **Running** | £100-120 | Full compute (D2s_v3, moderate). |
| **Deleted** | £0 | Requires 15-min redeploy. |

## 🏗️ Architecture

```
Internet User
    ↓
Windows App (or RDP Client)
    ↓
Azure Virtual Desktop Service (secure reverse connection)
    ↓
Personal Session Host VM (in isolated VNet)
    ↓
Your Desktop
```

**Security**: No public IPs, no inbound ports required, NSG minimal.

## 🎯 Use Cases

✅ **Remote work from alternate location** - Coffee shop, family visit, travel.
✅ **Temporary compute needs** - Project work, testing, demos.
✅ **Cost-sensitive scenarios** - Deallocate after use.
✅ **Personal productivity** - Persistent desktop, Entra ID auth.

❌ **Not for**: Pooled multi-user scenarios (use Pooled template instead).
❌ **Not for**: Always-on production (consider regular Azure VM pricing).

## 🔧 Key Features

- ✅ **Bicep IaC** - Reproducible, auditable infrastructure.
- ✅ **Parameterized** - Switch workload size (light/moderate) with one parameter.
- ✅ **Personal desktop** - Single user, persistent configuration.
- ✅ **Entra ID auth** - Cloud-native identity.
- ✅ **Deallocate pattern** - Stop VMs to save costs, resume instantly.
- ✅ **Automated scripts** - Deploy, start, deallocate, cleanup.
- ✅ **Minimal security** - Reverse connections, NSG included.
- ✅ **UK region** - Configured for ukwest by default.

## 📋 Prerequisites

- Azure CLI v2.40+.
- Azure subscription (Contributor role).
- PowerShell 5.1+.
- Entra ID user account.

## 🤝 Contributing

Found a bug? Have an idea? See [CONTRIBUTING.md](../CONTRIBUTING.md).

## 📄 License

MIT License - See [LICENSE](../LICENSE) for details.

---

**Documentation Links**:
- [Full README](../README.md) - Complete reference.
- [Deployment Guide](../DEPLOYMENT.md) - Step-by-step instructions.
- [GitHub Repository](https://github.com/markheydon/avd-occasional).

**Last Updated**: February 2026  
**Current Version**: 1.0
