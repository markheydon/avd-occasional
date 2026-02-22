# ===================================
# Stop AVD Session Host VMs
# Stops VMs to save compute costs while preserving configuration
# ===================================

param(
    [string]$ResourceGroupName = "avd-occasional-rg"
)

Write-Host "Stopping VMs in resource group: $ResourceGroupName..." -ForegroundColor Cyan

# Get all VMs in the resource group that match the pattern
$vms = az vm list --resource-group $ResourceGroupName --query "[?tags.project=='avd-occasional'].name" -o tsv

if (-not $vms) {
    Write-Host "No VMs found matching the AVD pattern in $ResourceGroupName." -ForegroundColor Yellow
    exit 0
}

# Convert single result to array
if ($vms -is [string]) {
    $vms = @($vms)
}

Write-Host "Found $($vms.Count) VM(s) to stop:" -ForegroundColor Yellow
$vms | ForEach-Object { Write-Host "  - $_" }
Write-Host ""

# Stop each VM
foreach ($vm in $vms) {
    Write-Host "Stopping $vm..." -ForegroundColor Yellow
    az vm deallocate --resource-group $ResourceGroupName --name $vm --no-wait
}

Write-Host "VM stop operations started. This may take a few minutes..." -ForegroundColor Green
Write-Host ""
Write-Host "To check status:" -ForegroundColor Cyan
Write-Host "  az vm list --resource-group $ResourceGroupName --query '[].{Name:name, PowerState:powerState}' -o table"
Write-Host ""
Write-Host "To restart VMs:" -ForegroundColor Cyan
Write-Host "  .\scripts\Start-AvdOccasional.ps1 -ResourceGroupName $ResourceGroupName"
