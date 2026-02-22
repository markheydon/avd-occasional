# Contributing

Contributions are welcome! Please follow these guidelines:

## Issues

- Use GitHub Issues for bug reports and feature requests.
- Include Azure region, Bicep CLI version, and error messages.

## Pull Requests

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/improve-template`).
- Test your changes with `az bicep build`, `az bicep lint`, and the `Deploy-AvdOccasional.ps1 -WhatIf` script.
4. Commit with clear messages.
5. Push and open a PR with description.

## Testing

Before submitting:
```powershell
# Validate Bicep syntax
az bicep lint infra/main.bicep

# Test deployment (dry-run)
.\\scripts\\Deploy-AvdOccasional.ps1 -WhatIf

# Clean up test resources
.\\scripts\\Remove-AvdOccasional.ps1 -Force
```

## Code Style

- Use camelCase for variable names.
- Add comments for non-obvious logic.
- Keep modules focused (one responsibility).
- Test with multiple parameter configurations.
