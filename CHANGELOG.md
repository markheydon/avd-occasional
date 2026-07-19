# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-07-19

### Added
- `AGENTS.md` — agent-agnostic project conventions for coding agents.
- `.agents/skills/bicep-implement/` — Bicep authoring and validation workflow skill.
- `.agents/skills/technical-writing/` — documentation and content writing skill with templates.
- CI job for PSScriptAnalyzer on `scripts/`.
- Documentation for maintaining the pinned AVD DSC gallery artifact URL.

### Changed
- Migrated from GitHub Copilot-specific config (`.github/copilot-instructions.md`, `.github/agents/`) to agent-agnostic layout.
- Updated moderate workload VM SKU from `Standard_D2s_v3` to `Standard_D2s_v5`.
- Aligned `Test-AvdSessionHost.ps1` REST API version to `2024-04-03` (matching Bicep templates).
- Pinned Azure CLI version in CI workflow.
- Updated documentation dates and fixed spelling ("publicly").

## [1.0.0] - 2026-02-21

### Added
- Initial release: Personal AVD desktop for occasional use.
- Bicep modules: VNet, NSG, Host Pool, Session Hosts.
- PowerShell deployment scripts (deploy, start, deallocate, cleanup).
- Cost optimization via deallocate functionality.
- Entra ID authentication support.
- UK region support with multi-region parameters.
- Single-user personal desktop.
- Parameterised workload sizing (light/moderate).
- Role assignment documentation and post-deployment configuration guide.
