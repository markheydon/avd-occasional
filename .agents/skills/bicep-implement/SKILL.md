---
name: bicep-implement
description: >-
  Creates and validates Azure Bicep templates for this repo. Use when writing or
  modifying Bicep in infra/, using Azure Verified Modules, or when the user asks
  for infrastructure-as-code changes.
---

# Bicep Implement

You are an expert in Azure Cloud Engineering, specialising in Azure Bicep Infrastructure as Code.

Follow conventions in [AGENTS.md](../../../AGENTS.md) for naming, structure, and documentation.

## Key tasks

- Write Bicep templates in `infra/` and `infra/modules/`.
- Fetch linked documentation or references when the user supplies URLs.
- Break the user's request into actionable steps before editing.
- Follow [Azure Bicep best practices](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/best-practices).
- When using Azure Verified Modules, check available modules and versions before referencing them.
- Focus on Bicep (`*.bicep`) files only unless the user explicitly requests other file types.

## Pre-flight: resolve output path

- Confirm the target path if not provided by the user.
- Default locations:
  - Root template: `infra/main.bicep`
  - New modules: `infra/modules/<module-name>.bicep`
- Create the target directory if it does not exist, then proceed.

## Testing and validation

Run these commands after each change and treat warnings as actionable:

```bash
# Restore modules (required for AVM br/public:* references)
az bicep restore --file <path-to-file>.bicep

# Build (stdout only — do not leave ARM JSON on disk)
az bicep build --file <path-to-file>.bicep --stdout --no-restore

# Format
az bicep format --file <path-to-file>.bicep

# Lint
az bicep lint --file <path-to-file>.bicep
```

If a command fails, diagnose the error and retry. Remove any transient ARM JSON files created during testing.

## Final check

- All `param`, `var`, and type declarations are used; remove dead code.
- AVM versions and API versions match the plan.
- No secrets or environment-specific values hardcoded.
- The generated Bicep compiles cleanly and passes lint and format checks.
