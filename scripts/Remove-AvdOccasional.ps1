# ===================================
# Remove AVD Resources
# Completely removes all AVD resources (use when truly done)
# ===================================

param(
    [string]$ResourceGroupName = "avd-occasional-rg",
    [switch]$Force
)

Write-Host "WARNING: This will PERMANENTLY DELETE all resources in $ResourceGroupName" -ForegroundColor Red
Write-Host ""

if (-not $Force) {
    $response = Read-Host "Are you sure you want to delete this resource group? (yes/no)"
    if ($response -ne "yes") {
        Write-Host "Deletion cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Deleting resource group: $ResourceGroupName..." -ForegroundColor Red
az group delete --name $ResourceGroupName --yes --no-wait

Write-Host "Resource group deletion initiated." -ForegroundColor Green
Write-Host ""
Write-Host "To check status:" -ForegroundColor Cyan
Write-Host "  az group show --name $ResourceGroupName 2>/dev/null || echo 'Already deleted'"
