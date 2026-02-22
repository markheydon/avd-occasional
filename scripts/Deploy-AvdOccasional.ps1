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
$deployParams = @(
    "--name", "avd-deploy-$(Get-Date -Format 'yyyyMMddhhmmss')"
    "--resource-group", $ResourceGroupName
    "--template-file", $TemplateFile
    "--parameters", $ParametersFile
    "--parameters", "environment=$Environment"
    "--parameters", "workloadSize=$WorkloadSize"
    "--parameters", "vmCount=$VmCount"
    "--parameters", "location=$Location"
    "--parameters", "adminUsername=$AdminUsername"
)

# Add admin password if provided
if ($AdminPassword) {
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($AdminPassword)
    )
    $deployParams += "--parameters", "adminPassword=$plainPassword"
}

# Add what-if flag if specified
if ($WhatIf) {
    Write-Host "Running in 'what-if' mode. No resources will be created." -ForegroundColor Yellow
    $deployParams += "--what-if"
}

# Deploy
Write-Host "Deploying AVD infrastructure..." -ForegroundColor Cyan
Write-Host "Parameters:" -ForegroundColor Yellow
Write-Host "  - Environment: $Environment"
Write-Host "  - Workload Size: $WorkloadSize"
Write-Host "  - VM Count: $VmCount"
Write-Host "  - Location: $Location"
Write-Host "  - Admin Username: $AdminUsername"
Write-Host "  - Admin Password: $(if($AdminPassword) { '***' } else { 'NOT PROVIDED' })"
Write-Host ""

# Prompt for admin password if not provided
if (-not $AdminPassword) {
    Write-Host "ERROR: Admin password is required for deployment." -ForegroundColor Red
    Write-Host "Please provide the admin password using -AdminPassword parameter" -ForegroundColor Red
    exit 1
}

az deployment group create @deployParams

if ($LASTEXITCODE -eq 0) {
    if ($WhatIf) {
        Write-Host "What-If completed successfully. No resources were created or modified." -ForegroundColor Green
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
