# Copilot Instructions for Bicep Development

This file provides guidelines for GitHub Copilot and other coding agents to ensure best practices are followed when working with Bicep files in this repository.

## General Guidelines

- **Use Bicep syntax** for all infrastructure-as-code definitions.
- **Follow Azure Bicep best practices** as outlined in the [official documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/best-practices).
- **Write clear, descriptive parameter and variable names**.
- **Add comments** to explain complex logic or resource configurations.
- **Use modules** to encapsulate reusable components.

## File Structure

- Place all Bicep files in the `/infra` directory.
- Use separate files for modules and main deployment templates.

## Naming Conventions

- Use `camelCase` for parameters and variables.
- Use `PascalCase` for resource names.

## Parameters and Outputs

- Define all configurable values as parameters.
- Provide default values where appropriate.
- Document parameters and outputs with `@description` decorators.

## Resource Management

- Use resource loops and conditions where possible to reduce duplication.
- Reference existing resources using `existing` keyword when needed.
- Avoid hardcoding values; use parameters or variables.

## Linting and Validation

- Ensure all Bicep files pass `bicep build` and `bicep lint` without errors or warnings.
- Validate deployments using test parameter files.

## Documentation

- Update `README.md` with any changes to deployment instructions or architecture.
- Document new modules with usage examples.

### Markdown Style Guide

**Bulleted Lists (Regular Content)**
- All bullet items must end with a full stop (period).
- Examples: "Install Azure CLI with the installer.", "Navigate to the portal."

**Task Lists (Numbered Steps)**
- Numbered task lists should NOT end with a full stop.
- Examples:
  1. Clone the repository
  2. Install dependencies
  3. Run the deployment script

**UK English Spelling**
- Use UK English spelling: "colour", "organisation", "customise", etc.
- Use consistent terminology (e.g., "Entra ID" not "Azure AD").

## PowerShell Scripts

All deployment and management scripts follow PowerShell cmdlet naming conventions:

- **Naming Pattern**: `Verb-AvdOccasional.ps1` (e.g., `Deploy-AvdOccasional.ps1`)
- **Verbs**: Use approved PowerShell verbs from the [official list](https://learn.microsoft.com/en-gb/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
  - `Deploy` - for infrastructure deployment
  - `Start` - for starting VMs
  - `Stop` - for stopping VMs (note: uses `az vm deallocate` internally to preserve config)
  - `Remove` - for deletion/cleanup operations
- **Location**: All scripts reside in the `scripts/` directory
- **Parameters**: Use `PascalCase` for parameter names (e.g., `$ResourceGroupName`, `$WaitForStartup`)
- **Documentation**: Include inline comments explaining the script's purpose and non-obvious logic

---

*These instructions help ensure consistency, maintainability, and best practices for all Bicep code and PowerShell scripts generated or modified in this repository.*