# ===================================
# Remove AVD Resources
# Completely removes all AVD resources (use when truly done)
# ===================================

param(
    [string]$ResourceGroupName = "avd-occasional-rg",
    [switch]$Force
)

# Check if resource group exists before attempting deletion
Write-Host "Checking if resource group exists..." -ForegroundColor Cyan
if (-not (az group show --name $ResourceGroupName 2>$null)) {
    Write-Host "Resource group not found. Nothing to delete." -ForegroundColor Yellow
    return
}

# Warn the user about permanent deletion
Write-Host "WARNING: This will PERMANENTLY DELETE all resources in $ResourceGroupName" -ForegroundColor Red
Write-Host ""

if (-not $Force) {
    $response = Read-Host "Are you sure you want to delete this resource group? (yes/no)"
    if ($response -ne "yes") {
        Write-Host "Deletion cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Delete the resource group and check for deletion status
Write-Host "Deleting resource group: $ResourceGroupName..." -ForegroundColor Red
az group delete --name $ResourceGroupName --yes --no-wait

Write-Host "Resource group deletion initiated." -ForegroundColor Green
Write-Host ""

Write-Host "Checking deletion status (timeout: 3 minutes)..." -ForegroundColor Cyan
$timeoutSeconds = 180
$intervalSeconds = 10
$elapsed = 0

while ($elapsed -lt $timeoutSeconds) {
    if (az group show --name $ResourceGroupName 2>$null) {
        Write-Host "  Resource group still exists. Waiting..." -ForegroundColor Yellow
        Start-Sleep -Seconds $intervalSeconds
        $elapsed += $intervalSeconds
    } else {
        Write-Host "  Resource group deleted successfully." -ForegroundColor Green
        return
    }
}

Write-Host "Timeout reached. Resource group may still exist." -ForegroundColor Yellow
Write-Host "Run: az group show --name $ResourceGroupName" -ForegroundColor Cyan
