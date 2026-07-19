# Agent Instructions

Guidelines for coding agents working in this repository.

## Project context

**avd-occasional** is an Infrastructure-as-Code template for cost-effective Azure Virtual Desktop (AVD) personal desktops aimed at occasional use. It deploys Entra ID-joined session hosts via Bicep, with PowerShell lifecycle scripts to deploy, start, deallocate, test, and remove resources.

| Directory | Purpose |
|-----------|---------|
| `infra/` | Bicep templates and modules |
| `scripts/` | PowerShell deployment and management scripts |
| `website/` | User-facing documentation site (Hugo / GitHub Pages) |

## Bicep conventions

- Use Bicep syntax for all infrastructure-as-code definitions.
- Follow [Azure Bicep best practices](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/best-practices).
- Place all Bicep files in `infra/`; use `infra/modules/` for reusable modules.
- Use `camelCase` for parameters and variables; `PascalCase` for resource names.
- Define configurable values as parameters with `@description()` decorators on parameters and outputs.
- Use modules, resource loops, and conditions to reduce duplication.
- Reference existing resources with the `existing` keyword when needed.
- Avoid hardcoding values; use parameters or variables.
- Ensure all Bicep files pass `az bicep lint` and `az bicep build` without errors or warnings.
- Update `README.md` and `website/content/` when deployment instructions or architecture change.
- Document new modules with usage examples.

## PowerShell conventions

All deployment and management scripts follow PowerShell cmdlet naming conventions:

- **Naming pattern**: `Verb-AvdOccasional.ps1` (e.g. `Deploy-AvdOccasional.ps1`).
- **Verbs**: Use [approved PowerShell verbs](https://learn.microsoft.com/en-gb/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands):
  - `Deploy` — infrastructure deployment.
  - `Start` — starting VMs.
  - `Stop` — stopping VMs (uses `az vm deallocate` internally to preserve config).
  - `Remove` — deletion and cleanup operations.
- **Location**: All scripts reside in `scripts/`.
- **Parameters**: Use `PascalCase` for parameter names (e.g. `$ResourceGroupName`, `$WaitForStartup`).
- **Documentation**: Include inline comments explaining the script's purpose and non-obvious logic.

## Markdown style

**Bulleted lists (regular content)**

- All bullet items must end with a full stop (period).
- Example: "Install Azure CLI with the installer."

**Task lists (numbered steps)**

- Numbered task lists should NOT end with a full stop.
- Example:
  1. Clone the repository
  2. Install dependencies
  3. Run the deployment script

**UK English spelling**

- Use UK English spelling: "colour", "organisation", "customise", etc.
- Use consistent terminology (e.g. "Entra ID" not "Azure AD").

## Testing

Before submitting changes, validate as described in [CONTRIBUTING.md](CONTRIBUTING.md):

```powershell
az bicep lint infra/main.bicep
az bicep build infra/main.bicep
```

For deployment changes, test with `-WhatIf` before a full deployment.

## Project skills

Use these skills for specialised workflows:

| Skill | When to use |
|-------|-------------|
| `bicep-implement` | Writing or modifying Bicep in `infra/`, using Azure Verified Modules, or infrastructure-as-code changes |
| `technical-writing` | Creating or editing `website/content/`, `README.md`, `CHANGELOG.md`, or other user-facing technical content |

Skills live in `.agents/skills/<skill-name>/SKILL.md`.
