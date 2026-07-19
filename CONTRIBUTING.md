# Contributing

Thank you for your interest in improving this project! Contributions are welcome.

## Before You Start

- See [AGENTS.md](AGENTS.md) for project conventions and guidelines.
- For end-user documentation support or clarifications, see [docs/](docs/) folder.

## Issues

- Use GitHub Issues for bug reports and feature requests.
- Include relevant details: Azure region, Bicep CLI version, PowerShell version, and full error messages.
- Search existing issues first to avoid duplicates.

## Pull Requests

1. Fork the repository.
2. Create a descriptive feature branch (`git checkout -b feature/improve-template`).
3. Make your changes.
4. Test thoroughly (see Testing section below).
5. Commit with clear, concise messages.
6. Push and open a PR with a description of changes and rationale.

## Testing

Before submitting a PR, validate all changes:

```powershell
# Lint Bicep files
az bicep lint infra/main.bicep

# Build Bicep to check for syntax errors
az bicep build infra/main.bicep

# Test deployment (dry-run, no resource creation)
$adminPassword = Read-Host "Enter admin password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword -WhatIf

# (Optional) Full deployment test
$adminPassword = Read-Host "Enter admin password" -AsSecureString
.\scripts\Deploy-AvdOccasional.ps1 -AdminPassword $adminPassword

# Verify resources
az resource list --resource-group avd-occasional-rg -o table

# Clean up test resources
.\scripts\Remove-AvdOccasional.ps1 -Force
```

## Code Style

- **Bicep files**: Follow [AGENTS.md](AGENTS.md)
  - Use `camelCase` for parameters and variables.
  - Use `PascalCase` for resource names.
  - Add `@description()` decorators to all parameters and outputs.
  - Use comments for non-obvious logic.
  - Keep modules focused (one responsibility).

- **PowerShell scripts**: Follow [AGENTS.md](AGENTS.md)
  - Use Verb-AvdOccasional naming pattern for scripts.
  - Use approved PowerShell verbs (Deploy, Start, Stop, Remove).
  - Use `PascalCase` for parameter names.
  - Include inline comments explaining purpose and non-obvious logic.

- **Markdown documentation**: Use UK English conventions.
  - Spelling: "organisation", "customise", "colour".
  - Terminology: Consistent terminology throughout (e.g., "Entra ID" not "Azure AD").
  - Links: Relative links between docs/ files; full URLs for external resources.

## Adding New Features

If adding new functionality:

1. Update relevant Bicep modules in `infra/`.
2. Update `infra/parameters.json` defaults if adding new parameters.
3. Update documentation in `docs/` and `README.md` if user-facing.
4. Test with multiple parameter configurations.
5. Update `CHANGELOG.md` with your changes.

## Submitting Documentation Changes

Documentation improvements are valuable! When updating docs:

1. Use UK English spelling throughout.
2. Ensure links between docs work correctly.
3. Keep explanations clear and concise.
4. Test that markdown renders correctly on GitHub.
5. Verify all code examples are copy-paste friendly.

See [docs/](docs/) for documentation structure.

## License

By contributing, you agree that your contributions will be licensed under the MIT License (see [LICENSE](LICENSE)).

---

Thank you for helping make this project better!

