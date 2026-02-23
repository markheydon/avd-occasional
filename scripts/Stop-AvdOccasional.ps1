# ===================================
# Stop AVD Session Host VMs
# Stops VMs to save compute costs while preserving configuration
# ===================================

param(
    [string]$ResourceGroupName = "avd-occasional-rg",
    [switch]$Force
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

# Interactive confirmation unless -Force is specified
if (-not $Force) {
    Write-Host "WARNING: This will stop VMs and delete associated Public IPs." -ForegroundColor Yellow
    Write-Host "This may temporarily disrupt service until VMs are restarted." -ForegroundColor Yellow
    Write-Host ""
    $confirmation = Read-Host "Are you sure you want to proceed? (yes/no)"
    
    if ($confirmation -ne 'yes') {
        Write-Host "Operation cancelled." -ForegroundColor Cyan
        exit 0
    }
    Write-Host ""
}

# Stop each VM
foreach ($vm in $vms) {
    Write-Host "Stopping $vm..." -ForegroundColor Yellow
    az vm deallocate --resource-group $ResourceGroupName --name $vm --no-wait
}

Write-Host "VM stop operations started. This may take a few minutes..." -ForegroundColor Green
Write-Host ""

Write-Host "Deallocating Public IPs to save costs..." -ForegroundColor Cyan
Write-Host "Note: This will save ~£2-3/month per VM while stopped." -ForegroundColor Gray
Write-Host ""

foreach ($vm in $vms) {
    # Get the NIC associated with the VM
    $nicId = az vm show --resource-group $ResourceGroupName --name $vm --query "networkProfile.networkInterfaces[0].id" -o tsv 2>$null
    
    if ($nicId) {
        $nicName = ($nicId -split '/')[-1]
        
        # Get the Public IP associated with the NIC
        $pipId = az network nic show --ids $nicId --query "ipConfigurations[0].publicIpAddress.id" -o tsv 2>$null
        
        if ($pipId) {
            $pipName = ($pipId -split '/')[-1]
            Write-Host "  Removing Public IP ($pipName) from $vm..." -ForegroundColor Yellow
            
            # Disassociate Public IP from NIC (must wait for this to complete)
            az network nic ip-config update `
                --resource-group $ResourceGroupName `
                --nic-name $nicName `
                --name ipconfig1 `
                --remove publicIpAddress 2>$null | Out-Null
            
            # Wait a moment for disassociation to complete
            Start-Sleep -Seconds 2
            
            # Delete the Public IP to stop billing
            Write-Host "  Deleting Public IP $pipName..." -ForegroundColor Yellow
            az network public-ip delete `
                --resource-group $ResourceGroupName `
                --name $pipName 2>$null
        }
        else {
            Write-Host "  No Public IP found for $vm" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Public IPs deallocated successfully." -ForegroundColor Green
Write-Host ""
Write-Host "To check status:" -ForegroundColor Cyan
Write-Host "  az vm list --resource-group $ResourceGroupName --query '[].{Name:name, PowerState:powerState}' -o table"
