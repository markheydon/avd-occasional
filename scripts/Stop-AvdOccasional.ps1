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

if ($vms -is [string]) {
    $vms = @($vms)
}


Write-Host "Found $($vms.Count) VM(s) to stop: $($vms -join ', ')" -ForegroundColor Yellow
Write-Host ""

# Interactive confirmation unless -Force is specified
if (-not $Force) {
    Write-Host "WARNING: This will stop VMs and delete associated Public IPs." -ForegroundColor Yellow
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
    Write-Host "Stopping $vm..." -NoNewline
    $stopOutput = az vm deallocate --resource-group $ResourceGroupName --name $vm --no-wait 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " Success" -ForegroundColor Green
    } else {
        Write-Host " Failed" -ForegroundColor Red
        Write-Host "    $stopOutput" -ForegroundColor Red
    }
}

# After initiating stop, handle Public IP cleanup
$ipDeletionErrors = @()

foreach ($vm in $vms) {
    # Get the NIC associated with the VM
    $nicId = az vm show --resource-group $ResourceGroupName --name $vm --query "networkProfile.networkInterfaces[0].id" -o tsv 2>$null
    if (-not $nicId) {
        Write-Host "  Warning: Could not find NIC for $vm" -ForegroundColor Yellow
        continue
    }
    $nicName = ($nicId -split '/')[-1]

    # Try to get the Public IP associated with the NIC (robust query)
    $pipId = az network nic show --ids $nicId --query "ipConfigurations[0].publicIPAddress.id" -o tsv 2>$null
    $pipName = $null
    if ($pipId) {
        $pipName = ($pipId -split '/')[-1]
    } else {
        # If not associated, try to infer the expected pip name from naming convention
        if ($nicName -match '(.+)-nic-(\d+)-(.+)') {
            $prefix = $matches[1]
            $index = $matches[2]
            $suffix = $matches[3]
            $pipName = "$prefix-pip-$index-$suffix"
        }
    }

    if (-not $pipName) {
        Write-Host "  No Public IP name could be determined for $vm" -ForegroundColor Gray
        continue
    }

    # Always attempt to disassociate if still associated
    if ($pipId) {
        Write-Host "Disassociating Public IP ($pipName) from $vm..." -NoNewline
        $disassociateSuccess = $false
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $disassociateOutput = az network nic ip-config update `
                --resource-group $ResourceGroupName `
                --nic-name $nicName `
                --name ipconfig1 `
                --remove publicIpAddress 2>&1
            if ($LASTEXITCODE -eq 0) {
                $disassociateSuccess = $true
                break
            } else {
                if ($attempt -lt 3) {
                    Start-Sleep -Seconds 2
                }
            }
        }
        if ($disassociateSuccess) {
            Write-Host " Success" -ForegroundColor Green
        } else {
            Write-Host " Failed" -ForegroundColor Red
            Write-Host "    $disassociateOutput" -ForegroundColor Red
            $ipDeletionErrors += "Failed to disassociate $pipName from $vm (but will attempt deletion)"
        }

        # Wait for actual disassociation (NIC property to be empty)
        $maxWait = 30  # seconds
        $waited = 0
        $stillAssociated = $true
        while ($waited -lt $maxWait) {
            $currentPipId = az network nic show --ids $nicId --query "ipConfigurations[0].publicIpAddress.id" -o tsv 2>$null
            if (-not $currentPipId) {
                $stillAssociated = $false
                break
            }
            Start-Sleep -Seconds 3
            $waited += 3
        }
        if ($stillAssociated) {
            Write-Host "    WARNING: Public IP still associated after waiting $maxWait seconds." -ForegroundColor Red
        }
    }

    # Now always attempt to delete the Public IP resource if it exists in the RG
    $pipExists = az network public-ip show --resource-group $ResourceGroupName --name $pipName --query "id" -o tsv 2>$null
    if ($pipExists) {
        Write-Host "Deleting Public IP ($pipName)..." -NoNewline
        $deleteSuccess = $false
        for ($attempt = 1; $attempt -le 3; $attempt++) {
            $deleteOutput = az network public-ip delete `
                --resource-group $ResourceGroupName `
                --name $pipName 2>&1
            if ($LASTEXITCODE -eq 0) {
                $deleteSuccess = $true
                break
            } else {
                if ($deleteOutput -like "*NotFound*" -or $deleteOutput -like "*does not exist*") {
                    $deleteSuccess = $true
                    break
                }
                if ($attempt -lt 3) {
                    Start-Sleep -Seconds 3
                }
            }
        }
        if ($deleteSuccess) {
            Write-Host " Success" -ForegroundColor Green
        } else {
            Write-Host " Failed" -ForegroundColor Red
            Write-Host "    $deleteOutput" -ForegroundColor Red
            $ipDeletionErrors += "Failed to delete $pipName. Error: $deleteOutput"
        }
    } else {
        # Only show if not already deleted and not expected
        # Write-Host "  Public IP ($pipName) does not exist in resource group (already deleted)" -ForegroundColor Gray
    }
}

Write-Host ""

# Report final status
if ($ipDeletionErrors.Count -eq 0) {
    Write-Host "Public IPs deallocated successfully." -ForegroundColor Green
}
else {
    Write-Host "VM stop completed, but some Public IP operations had issues:" -ForegroundColor Yellow
    $ipDeletionErrors | ForEach-Object { Write-Host "  WARNING: $_" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "VMs are stopped. Public IP cleanup may be incomplete." -ForegroundColor Yellow
    Write-Host "You can re-run this script to retry IP deletion." -ForegroundColor Cyan
}

Write-Host ""
Write-Host "To check VM status (including power state):" -ForegroundColor Cyan
Write-Host "  az vm list --resource-group $ResourceGroupName --show-details --query '[].{Name:name, PowerState:powerState}' -o table"
Write-Host ""
Write-Host "To see remaining Public IPs:" -ForegroundColor Cyan
Write-Host "  az network public-ip list --resource-group $ResourceGroupName --query '[].{Name:name, IP:ipAddress}' -o table"