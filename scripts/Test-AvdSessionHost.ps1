<#
.SYNOPSIS
    Diagnoses AVD session host connectivity and status issues.

.DESCRIPTION
    Checks session host status, VM power state, extension status, and RDP properties
    to identify why a session host might be unavailable. Can auto-discover resources if run without parameters.

.PARAMETER ResourceGroupName
    Name of the resource group containing AVD resources. Defaults to 'avd-occasional-rg'.

.PARAMETER HostPoolName
    Name of the AVD host pool. Auto-discovered if not specified.

.PARAMETER VmName
    Name of the session host VM to diagnose. Auto-discovered if not specified.

.EXAMPLE
    .\Test-AvdSessionHost.ps1
    
.EXAMPLE
    .\Test-AvdSessionHost.ps1 -ResourceGroupName avd-occasional-rg -HostPoolName avd-dev-hp-zx4itrg75d2kc -VmName avd-dev-vm-0-zx4itrg75d2kc
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = 'avd-occasional-rg',

    [Parameter(Mandatory = $false)]
    [string]$HostPoolName,

    [Parameter(Mandatory = $false)]
    [string]$VmName
)

Write-Host "`n=== AVD Session Host Diagnostics ===" -ForegroundColor Cyan

# Get subscription ID (needed for auto-discovery and later queries)
$subscriptionId = az account show --query id -o tsv

# Auto-discover resources if not specified
if (-not $HostPoolName -or -not $VmName) {
    Write-Host "Auto-discovering AVD resources in resource group: $ResourceGroupName`n" -ForegroundColor Yellow
    
    # Discover host pool if not specified
    if (-not $HostPoolName) {
        Write-Host "Discovering host pool..." -ForegroundColor Gray
        $hostPoolsJson = az desktopvirtualization hostpool list `
            --resource-group $ResourceGroupName `
            --query "[].name" `
            -o json 2>$null
        
        if ($hostPoolsJson) {
            $hostPools = $hostPoolsJson | ConvertFrom-Json
            if ($hostPools -is [array] -and $hostPools.Count -gt 0) {
                $HostPoolName = $hostPools[0]
            } elseif ($hostPools -is [string]) {
                $HostPoolName = $hostPools
            }
        }
        
        if ($HostPoolName) {
            Write-Host "  Found: $HostPoolName" -ForegroundColor Green
        } else {
            Write-Error "No host pools found in resource group: $ResourceGroupName"
            exit 1
        }
    }
    
    # Discover VMs if not specified
    if (-not $VmName) {
        Write-Host "Discovering VMs..." -ForegroundColor Gray
        $vmsJson = az vm list `
            --resource-group $ResourceGroupName `
            --query "[?starts_with(name, 'avd-')].name" `
            -o json 2>$null
        
        if ($vmsJson) {
            $vms = $vmsJson | ConvertFrom-Json
            if ($vms -is [array] -and $vms.Count -gt 0) {
                $VmName = $vms[0]
                Write-Host "  Found: $VmName" -ForegroundColor Green
                
                if ($vms.Count -gt 1) {
                    Write-Host "  Note: $($vms.Count) VMs found, testing first one. Others: $($vms[1..$($vms.Count-1)] -join ', ')" -ForegroundColor Gray
                }
            } elseif ($vms -is [string]) {
                $VmName = $vms
                Write-Host "  Found: $VmName" -ForegroundColor Green
            }
        }
        
        if (-not $VmName) {
            Write-Error "No AVD VMs found in resource group: $ResourceGroupName"
            exit 1
        }
    }
    Write-Host ""
}

Write-Host "Resource Group: $ResourceGroupName"
Write-Host "Host Pool: $HostPoolName"
Write-Host "VM Name: $VmName`n"

# Check VM power state
Write-Host "Checking VM power state..." -ForegroundColor Yellow
$vmPowerState = az vm get-instance-view `
    --resource-group $ResourceGroupName `
    --name $VmName `
    --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" `
    -o tsv

Write-Host "  Power State: $vmPowerState" -ForegroundColor $(if ($vmPowerState -eq "VM running") { "Green" } else { "Red" })

# Check VM extensions
Write-Host "`nChecking VM extensions..." -ForegroundColor Yellow
$extensions = az vm extension list `
    --resource-group $ResourceGroupName `
    --vm-name $VmName `
    --query "[].{Name:name, State:provisioningState, Type:type}" `
    -o json | ConvertFrom-Json

foreach ($ext in $extensions) {
    $color = if ($ext.State -eq "Succeeded") { "Green" } else { "Red" }
    Write-Host "  [$($ext.Name)]: $($ext.State)" -ForegroundColor $color
}

# Check session host status
Write-Host "`nChecking session host status in AVD..." -ForegroundColor Yellow
$sessionHostUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName/sessionHosts?api-version=2023-09-05"

$sessionHosts = az rest --method get --url $sessionHostUrl --query "value" -o json | ConvertFrom-Json
$targetHost = $sessionHosts | Where-Object { $_.name -like "*$($VmName.Split('-')[0..3] -join '-')*" }

if ($targetHost) {
    $statusColor = if ($targetHost.properties.status -eq "Available") { "Green" } else { "Red" }
    Write-Host "  Status: $($targetHost.properties.status)" -ForegroundColor $statusColor
    Write-Host "  Update State: $($targetHost.properties.updateState)"
    Write-Host "  Last Heartbeat: $($targetHost.properties.lastHeartBeat)"
    Write-Host "  OS Version: $($targetHost.properties.osVersion)"
} else {
    Write-Host "  ERROR: Session host not found in host pool!" -ForegroundColor Red
}

# Check host pool RDP properties
Write-Host "`nChecking host pool RDP properties..." -ForegroundColor Yellow
$hostPoolUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DesktopVirtualization/hostPools/$HostPoolName`?api-version=2023-09-05"
$hostPool = az rest --method get --url $hostPoolUrl -o json | ConvertFrom-Json

$rdpProps = $hostPool.properties.customRdpProperty
Write-Host "  Custom RDP Properties: $rdpProps"

# Check for Entra ID join properties
if ($rdpProps -match "targetisaadjoined:i:1" -and $rdpProps -match "enablerdsaadauth:i:1") {
    Write-Host "  Entra ID auth properties: CONFIGURED" -ForegroundColor Green
} else {
    Write-Host "  Entra ID auth properties: MISSING" -ForegroundColor Red
    Write-Host "  Required: targetisaadjoined:i:1;enablerdsaadauth:i:1" -ForegroundColor Yellow
}

# Check VM Entra ID extension
Write-Host "`nChecking Entra ID join status..." -ForegroundColor Yellow
$aadExt = $extensions | Where-Object { $_.Name -eq "AADLoginForWindows" }
if ($aadExt) {
    Write-Host "  AADLoginForWindows extension: $($aadExt.State)" -ForegroundColor Green
} else {
    Write-Host "  AADLoginForWindows extension: NOT FOUND" -ForegroundColor Red
}

Write-Host "`n=== Recommendations ===" -ForegroundColor Cyan

if ($vmPowerState -ne "VM running") {
    Write-Host "• VM is not running. Start the VM first." -ForegroundColor Yellow
}

if ($null -ne $targetHost) {
    if ($targetHost.properties.status -ne "Available") {
        Write-Host "• Session host status is '$($targetHost.properties.status)'" -ForegroundColor Yellow
        
        if (-not ($rdpProps -match "targetisaadjoined:i:1" -and $rdpProps -match "enablerdsaadauth:i:1")) {
            Write-Host "• Update host pool with Entra ID RDP properties in avd-pool.bicep" -ForegroundColor Yellow
            Write-Host "  Add: enablerdsaadauth:i:1 to customRdpProperty" -ForegroundColor Cyan
        }
        
        if ($targetHost.properties.lastHeartBeat) {
            try {
                $lastHeartbeat = [System.DateTimeOffset]::Parse(
                    $targetHost.properties.lastHeartBeat,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::RoundtripKind
                )
                $minutesSinceHeartbeat = ([System.DateTimeOffset]::UtcNow - $lastHeartbeat).TotalMinutes

                if ($minutesSinceHeartbeat -lt 5) {
                    Write-Host "• AVD agent is active (heartbeat $([Math]::Round($minutesSinceHeartbeat, 1)) minutes ago)" -ForegroundColor Green
                    Write-Host "• The session host may take a few more minutes to become Available" -ForegroundColor Yellow
                    Write-Host "  Wait 2-5 minutes and run this diagnostic again" -ForegroundColor Cyan
                } elseif ($minutesSinceHeartbeat -lt 15) {
                    Write-Host "• AVD agent last reported $([Math]::Round($minutesSinceHeartbeat)) minutes ago" -ForegroundColor Yellow
                    Write-Host "  Wait a bit longer or restart the VM if it doesn't recover" -ForegroundColor Cyan
                } else {
                    Write-Host "• AVD agent hasn't sent heartbeat in $([Math]::Round($minutesSinceHeartbeat)) minutes" -ForegroundColor Red
                    Write-Host "  Restart the VM to reinitialize the agent:" -ForegroundColor Cyan
                    Write-Host "  .\scripts\Stop-AvdOccasional.ps1 -ResourceGroupName $ResourceGroupName" -ForegroundColor Cyan
                    Write-Host "  .\scripts\Start-AvdOccasional.ps1 -ResourceGroupName $ResourceGroupName" -ForegroundColor Cyan
                }
            }
            catch {
                Write-Host "• Last Heartbeat: $($targetHost.properties.lastHeartBeat) (unable to parse datetime)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "• No heartbeat data available from AVD agent" -ForegroundColor Red
        }
    } else {
        Write-Host "• Session host is Available and ready for connections!" -ForegroundColor Green
    }
} else {
    Write-Host "• Session host not found in host pool. Verify VM is correctly associated with the host pool." -ForegroundColor Red
}
Write-Host ""