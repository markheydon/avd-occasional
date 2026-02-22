# ===================================
# Start AVD Session Host VMs
# Starts deallocated VMs for work sessions
# ===================================

param(
    [string]$ResourceGroupName = "avd-occasional-rg",
    [switch]$WaitForStartup
)

Write-Host "Starting VMs in resource group: $ResourceGroupName..." -ForegroundColor Cyan

# Get all deallocated VMs
$vms = az vm list --resource-group $ResourceGroupName --query "[?tags.project=='avd-occasional'].name" -o tsv

if (-not $vms) {
    Write-Host "No VMs found matching the AVD pattern in $ResourceGroupName." -ForegroundColor Yellow
    exit 0
}

# Convert single result to array
if ($vms -is [string]) {
    $vms = @($vms)
}

Write-Host "Found $($vms.Count) VM(s) to start:" -ForegroundColor Yellow
$vms | ForEach-Object { Write-Host "  - $_" }
Write-Host ""

# Start each VM
foreach ($vm in $vms) {
    Write-Host "Starting $vm..." -ForegroundColor Yellow
    az vm start --resource-group $ResourceGroupName --name $vm --no-wait
}

Write-Host "VM startup operations initiated." -ForegroundColor Green
Write-Host ""

if ($WaitForStartup) {
    Write-Host "Waiting for VMs to start (this may take a few minutes)..." -ForegroundColor Cyan
    foreach ($vm in $vms) {
        Write-Host "Waiting for $vm..." -ForegroundColor Yellow
        az vm wait --updated --ids $(az vm show --resource-group $ResourceGroupName --name $vm --query id -o tsv)
    }
    Write-Host "All VMs started successfully!" -ForegroundColor Green
}
else {
    Write-Host "To check status:" -ForegroundColor Cyan
    Write-Host "  az vm list --resource-group $ResourceGroupName --query '[].{Name:name, PowerState:powerState}' -o table"
}
