# ===================================
# Deploy AVD Infrastructure
# This script deploys the complete AVD infrastructure using Bicep
# ===================================

param(
    [string]$ResourceGroupName = "avd-occasional-rg",
    [string]$Location = "ukwest",
    [string]$TemplateFile = "./infra/main.bicep",
    [string]$ParametersFile = "./infra/parameters.json",
    [ValidateSet('dev', 'test', 'prod')]
    [string]$Environment = "dev",
    [ValidateSet('light', 'moderate')]
    [string]$WorkloadSize = "moderate",
    [int]$VmCount = 1,
    [string]$AdminUsername = "avdadmin",
    [securestring]$AdminPassword,
    [switch]$UseHybridBenefit,
    [switch]$WhatIf
)

# Import required modules
Write-Host "Initialising deployment..." -ForegroundColor Cyan

# Check if resource group exists
$rgExists = az group exists --name $ResourceGroupName | ConvertFrom-Json
if (-not $rgExists) {
    Write-Host "Creating resource group: $ResourceGroupName in $Location..." -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location | Out-Null
}
else {
    Write-Host "Resource group $ResourceGroupName already exists." -ForegroundColor Green
}

# Build deployment parameters
# Note: Parameters defined in parameters.json should not be overridden here with defaults.
# Only override with command-line values if explicitly different from script parameters.
$deployParams = @(
    "--name", "avd-deploy-$(Get-Date -Format 'yyyyMMddhhmmss')"
    "--resource-group", $ResourceGroupName
    "--template-file", $TemplateFile
    "--parameters", "@$ParametersFile"
)

# Only pass parameters that override the file values if user explicitly provided them
# Check if user provided non-default values
if ($PSBoundParameters.ContainsKey('Environment')) {
    $deployParams += "--parameters", "environment=$Environment"
}
if ($PSBoundParameters.ContainsKey('WorkloadSize')) {
    $deployParams += "--parameters", "workloadSize=$WorkloadSize"
}
if ($PSBoundParameters.ContainsKey('VmCount')) {
    $deployParams += "--parameters", "vmCount=$VmCount"
}
if ($PSBoundParameters.ContainsKey('Location')) {
    $deployParams += "--parameters", "location=$Location"
}
if ($PSBoundParameters.ContainsKey('AdminUsername')) {
    $deployParams += "--parameters", "adminUsername=$AdminUsername"
}

# Always pass admin password if provided (not typically in parameters.json for security)
if ($AdminPassword) {
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($AdminPassword)
    )
    $deployParams += "--parameters", "adminPassword=$plainPassword"
}

# Add what-if flag if specified
if ($WhatIf) {
    Write-Host "What-If: Running in 'what-if' mode. No resources will be created." -ForegroundColor Yellow
    $deployParams += "--what-if"
}

# Deploy
Write-Host "Deploying AVD infrastructure..." -ForegroundColor Cyan
Write-Host "Base configuration: $ParametersFile" -ForegroundColor Yellow

# Only show overrides
$overrides = @()
if ($PSBoundParameters.ContainsKey('Environment')) { $overrides += "Environment: $Environment" }
if ($PSBoundParameters.ContainsKey('WorkloadSize')) { $overrides += "Workload Size: $WorkloadSize" }
if ($PSBoundParameters.ContainsKey('VmCount')) { $overrides += "VM Count: $VmCount" }
if ($PSBoundParameters.ContainsKey('Location')) { $overrides += "Location: $Location" }
if ($PSBoundParameters.ContainsKey('AdminUsername')) { $overrides += "Admin Username: $AdminUsername" }

if ($overrides.Count -gt 0) {
    Write-Host "Overrides:" -ForegroundColor Yellow
    $overrides | ForEach-Object { Write-Host "  - $_" }
}
else {
    Write-Host "No parameter overrides (using all values from file)" -ForegroundColor Green
}

Write-Host "  - Admin Password: $(if($AdminPassword) { '***' } else { 'NOT PROVIDED' })"
Write-Host "  - What-If Mode: $WhatIf"
Write-Host ""

# Show full list of deployment parameters in a readable format (only if debug)
# Write-Host "Full deployment parameters:" -ForegroundColor Yellow
# for ($i = 0; $i -lt $deployParams.Count; $i++) {
#     $param = $deployParams[$i]
    
#     # Check if this is a flag with a value following it
#     if ($param -like '--*' -and ($i + 1) -lt $deployParams.Count -and -not $deployParams[$i + 1].StartsWith('--')) {
#         $value = $deployParams[$i + 1]
        
#         # Mask adminPassword for security
#         if ($param -eq '--parameters' -and $value -like 'adminPassword=*') {
#             Write-Host "  - $param adminPassword=***" -ForegroundColor Yellow
#         }
#         else {
#             Write-Host "  - $param $value" -ForegroundColor Yellow
#         }
#         $i++ # Skip the next item since we've already processed it
#     }
#     elseif ($param.StartsWith('--')) {
#         # Standalone flag (like --what-if)
#         Write-Host "  - $param" -ForegroundColor Yellow
#     }
# }


# Prompt for admin password if not provided
if (-not $AdminPassword) {
    Write-Host "Admin password was not provided. You will be prompted to enter it now." -ForegroundColor Yellow
    $AdminPassword = Read-Host -AsSecureString -Prompt "Enter the local administrator password for the session host VMs"
}

az deployment group create @deployParams

if ($LASTEXITCODE -eq 0) {
    if ($WhatIf) {
        Write-Host "What-If: What-If completed successfully. No resources were created or modified." -ForegroundColor Green
    }
    else {
        Write-Host "Deployment completed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "IMPORTANT: Configure access before connecting" -ForegroundColor Yellow
        Write-Host "Two role assignments are required for Entra ID-joined AVD:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Assign 'Desktop Virtualization User' role to Application Group"
        Write-Host "   - Portal: Resource Groups > $ResourceGroupName > Desktop App Group > IAM"
        Write-Host ""
        Write-Host "2. Assign 'Virtual Machine User Login' role to each VM"
        Write-Host "   - Portal: Resource Groups > $ResourceGroupName > VM > IAM"
        Write-Host "   - CLI: See README.md for PowerShell commands"
        Write-Host ""
        Write-Host "3. Wait 5-10 minutes for role propagation"
        Write-Host ""
        Write-Host "4. Launch Windows App and connect to 'Personal Desktop'"
        Write-Host ""
        Write-Host "To stop VMs (save cost): .\scripts\Stop-AvdOccasional.ps1 -ResourceGroupName $ResourceGroupName"
        Write-Host "To delete everything: az group delete --name $ResourceGroupName"
    }
}
else {
    Write-Host "Deployment failed. Check error messages above." -ForegroundColor Red
    exit 1
}
