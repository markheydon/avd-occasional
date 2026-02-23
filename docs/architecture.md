---
layout: default
title: Architecture Overview
---

# Architecture Overview

Understand the infrastructure components deployed by this template and how they work together to provide a secure, cost-optimised Azure Virtual Desktop environment.

## High-Level Architecture

```
Internet User
    ↓
[Azure Virtual Desktop Client]
    ├─ Windows App (Recommended)
    ├─ Web Client
    └─ RDP Client
    ↓
[Azure Virtual Desktop Service]
    (Secure reverse connection, no public IPs)
    ↓
[Azure Virtual Network (10.0.0.0/16)]
    ├─ Subnet: 10.0.1.0/24
    ├─ Session Host VMs (Entra ID joined)
    ├─ Public IPs (outbound only)
    └─ Network Security Group
    ↓
[Your Desktop Environment]
```

**Key principle:** VMs do not accept inbound connections. All connections originate from the VM to the Azure Virtual Desktop service.

## Component Overview

### Network Layer

**Virtual Network (VNet)**
- CIDR block: `10.0.0.0/16`
- Isolated address space for all resources
- No peering or routing to on-premises (cloud-native design)

**Subnet**
- CIDR block: `10.0.1.0/24`
- Hosts session host VMs and network interfaces
- Has service endpoints for optimised routing to Azure services (Storage, Key Vault, Entra ID)
- `defaultOutboundAccess` set to `false` (explicit outbound connectivity required)

**Network Security Group (NSG)**
- Default policy: Deny all inbound traffic
- Allows all outbound traffic to internet
- Allows service-tagged outbound traffic (Azure services)
- VMs are inaccessible from the internet (no RDP ports exposed)

**Public IPs**
- Type: Standard (public IP addresses)
- Purpose: Outbound internet connectivity only
- Lifecycle: Automatically deleted when VMs are stopped (cost optimisation)
- Security: NSG blocks all inbound, so IPs are "invisible" to external connections

### Azure Virtual Desktop Layer

**Host Pool**
- Type: Personal (each user has a dedicated VM)
- Assignment: Direct assignment (not pooled)
- Operating system: Windows 11 Enterprise multi-session (25H2)
- Max session hosts: Configurable (default: 1, up to 5)

**Workspace**
- Container for application groups
- Referenced by user subscriptions in Windows App or web portal
- One workspace per deployment

**Application Group**
- Type: Desktop (not remote apps)
- Linked to host pool
- Users assigned here gain access to the desktop

**Registration Token**
- Automatically generated and valid for 4 hours
- Used by CustomScript extension on VMs to register with the host pool

### Compute Layer

**Session Host VMs**
- Operating system: Windows 11 Enterprise (multi-session capable)
- Count: Configurable (1–5, default: 1)
- Size: `Standard_D2s_v3` (moderate) or `Standard_B2s` (light)
- Boot method: UEFI with Secure Boot (Trusted Launch enabled)
- OS disk: Standard SSD, 30 GB
- Boot diagnostics: Enabled (diagnostics logs to managed storage)

**VM Identity**
- User-assigned managed identity
- Permissions: Scoped to resource group (for DSC script uploads)
- Updates: No credentials required in code/parameters

**VM Extensions**
- CustomScript extension: Installs AVD Agent and BootLoader for Entra ID joining
- Single extension per VM (combined script due to Azure limitation)

## Cost Model

### Monthly Costs by Component

| Component | Deallocated | Running | Notes |
|-----------|-----------|---------|-------|
| **Session Host VM** | £0 | £90–120 | Largest cost driver (D2s_v3) |
| **OS Disk** | £2–3 | £2–3 | Always charged |
| **Public IP** | £0 | £2–3 | Deleted when stopped |
| **Network & Services** | £0 | £0 | Free (VNet, NSG, AVD service) |
| **Total** | **£2–3** | **£94–126** | **98% savings when deallocated** |

### Cost Optimisation Features

**Public IP Lifecycle Management**
- Public IPs are **deleted** when you stop VMs (using `Stop-AvdOccasional.ps1`)
- Public IPs are **created** when you start VMs (using `Start-AvdOccasional.ps1`)
- This saves ~£2–3/month during idle periods

**Workload Sizing**
- **Light workload**: `Standard_B2s` (~£35/month active)
- **Moderate workload**: `Standard_D2s_v3` (~£100–120/month active)
- Switch between sizes by editing `parameters.json` and redeploying

**Deallocate vs. Delete**
- **Deallocate** (recommended): Stop VM compute, keep disks and configuration (~£2–3/month) – resumable in 2–3 minutes
- **Delete**: Remove everything (~£0/month) – requires 15–20 minute redeploy

## Security Architecture

### Authentication & Access Control

**Entra ID-Joined VMs**
- VMs are cloud-native joined to Entra ID (not on-premises AD)
- Users authenticate with Entra ID credentials (same as Microsoft 365)
- Supports passwordless authentication (Windows Hello, FIDO2)
- No VPN or directory synchronisation required

**Role-Based Access Control (RBAC)**
- Users must have two roles assigned (see [Prerequisites](prerequisites.md) for details):
  - **Desktop Virtualization User** – Access AVD workspace
  - **Virtual Machine User Login** – Log into VMs
- Roles are independently assignable (granular access control)

### Network Security

**Reverse Connection Model**
- Users do not initiate connections to VMs
- VMs establish persistent reverse connections to Azure Virtual Desktop service
- All traffic flows through secure Azure infrastructure (no user-VM direct connections)

**Network Segmentation**
- VMs are isolated in private subnet (no direct internet routes)
- All outbound traffic goes through Public IP (singular egress point)
- All inbound traffic is blocked at NSG (except reverse AVD connections)

**Data Encryption**
- VM OS disks encrypted at rest by default (Azure managed encryption)
- RDP/AVD protocol uses TLS for in-transit encryption
- Network traffic through Azure backbone (not exposed to internet)

**Administrative Access**
- No RDP ports exposed publicly
- No SSH or Bastion access by default
- Administrative tasks done via Azure Portal or PowerShell (through Entra ID)

### Compliance Features

**Trusted Launch VMs**
- Secure Boot: Enabled (prevents unsigned kernel modifications)
- vTPM: Enabled (virtual Trusted Platform Module for OS attestation)
- Measurement Boot: Enabled (validates bootloader chain)

**Audit & Diagnostics**
- Boot diagnostics enabled (stored in managed storage account)
- Azure Virtual Desktop diagnostic logs available (query via Log Analytics if configured)
- Resource tagging for cost tracking and compliance

## Resource Naming & Lifecycle

### Naming Convention

Resource names are deterministically generated using `uniqueString(resourceGroup().id)`:

```
avd-[environment]-[resource]-[uniqueString]

Examples:
  avd-dev-vnet-abc123m  (VNet)
  avd-dev-nsg-abc123m   (NSG)
  avd-dev-vm-0-abc123m  (First session host)
  avd-dev-dag-abc123m   (Application group)
  avd-dev-hp-abc123m    (Host pool)
```

**Benefits:**
- Stable names across redeployments (idempotency)
- No resource name collisions when multiple deployments in same region
- Deterministic resource IDs for automation

### Idempotency

This template is **fully idempotent**:

- Running deployment multiple times creates/updates the same resource set (no duplicates)
- Failed deployments can be safely rerun
- Naming is stable, so resource IDs are predictable
- Suitable for CI/CD and automated operations

## Resource Dependency Graph

```
Resource Group (avd-occasional-rg)
├── Virtual Network
│   ├── Subnet ──────────────────────────────┐
│   └── Service Endpoints                    │
├── Network Security Group ──────────────────┤
├── Host Pool                                │
├── Workspace ──→ Application Group ────────┐│
│                                            ││
├── Session Host VMs (1-5)                   ││
│   ├─ Network Interface ←─────┬─────────────┘│
│   ├─ Public IP (managed lifecycle)          │
│   ├─ OS Disk                                │
│   ├─ Managed Identity                       │
│   └─ Custom Script Extension                │
│       └─ [Installs AVD Agent via Host Pool←─┘
│           Registration Token]
```

**Deployment order:**
1. Network (VNet, NSG, Subnet with Service Endpoints)
2. Host Pool (creates registration token)
3. Workspace
4. Application Group
5. VMs and network interfaces
6. Public IPs
7. VM extensions (registers with host pool)

## Outbound Connectivity (March 2026 Compliance)

Starting March 31, 2026, Azure requires **explicit outbound connectivity** for new virtual networks. This template implements compliance through:

### Explicit Outbound Methods

**1. Standard Public IPs on NICs**
- Each VM has a Standard Public IP attached to its network interface
- Public IPs provide explicit outbound NAT gateway
- Lifecycle managed by Start/Stop scripts

**2. Service Endpoints**
- Optimised routes to Azure services (no cost)
- Services: Storage (DSC downloads), Key Vault, Entra ID (for authentication)
- Reduces data egress charges

**3. Network Defaults**
- VNet subnet has `defaultOutboundAccess: false` (explicitly disabled)
- Forces all outbound to use Public IP (no hidden implicit access)
- Aligns with "zero-trust" principles

### Why This Approach

✅ **Compliant** – Meets March 2026 Azure requirements  
✅ **Cost-optimised** – IPs deleted when VMs stopped (saves ~£2–3/month)  
✅ **Transparent** – All outbound routes visible and auditable  
✅ **Functional** – Full internet access for updates, downloads, browsing  
✅ **Secure** – Combined with NSG, provides tight security posture

## Deployment Customisation Options

### Configurable Parameters

| Parameter | Default | Allowed Values | Cost Impact | Use Case |
|-----------|---------|-----------------|------------|----------|
| `environment` | `dev` | `dev`, `test`, `prod` | None | Environment naming |
| `workloadSize` | `moderate` | `light`, `moderate` | **HIGH** | Light: £35/mo, Moderate: £100–120/mo |
| `location` | `ukwest` | Any Azure region | Regional pricing variance | Geographic proximity |
| `vmCount` | `1` | `1`–`5` | **HIGH** | Linear cost scaling (£100/mo per VM added) |
| `adminUsername` | `avdadmin` | Any valid Windows name | None | VM admin login |
| `tags` | Auto-set | Custom tags object | None | Cost tracking, compliance |

### Not Customisable (By Design)

- **Entra ID membership** – Always Entra ID-joined (cloud-native only)
- **Public IP type** – Always Standard (for explicit outbound compliance)
- **VNet CIDR** – Fixed at `10.0.0.0/16` (adjustable in Bicep, not parameters)
- **Host Pool type** – Always Personal (single-user, not pooled)

## Related Documentation

- [Quick Start](quickstart.md) – Deployment steps
- [Deployment Details](deployment-detailed.md) – Technical deployment walkthrough
- [Troubleshooting](troubleshooting.md) – Common issues and solutions
- [Scripts Reference](scripts.md) – PowerShell commands for lifecycle management

---

**Last Updated**: February 2026
