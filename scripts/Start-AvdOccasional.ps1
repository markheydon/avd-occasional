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
$vms = az vm list --resource-group $ResourceGroupName --show-details --query "[?tags.project=='avd-occasional' && powerState=='VM deallocated'].name" -o tsv

if (-not $vms) {
    Write-Host "No VMs found matching the AVD pattern in $ResourceGroupName." -ForegroundColor Yellow
    exit 0
}

if ($vms -is [string]) {
    $vms = @($vms)
}

Write-Host "Found $($vms.Count) VM(s) to start: $($vms -join ', ')" -ForegroundColor Yellow
Write-Host ""

# Allocate Public IPs for outbound connectivity before starting VMs
Write-Host "Allocating Public IPs for outbound connectivity..." -ForegroundColor Cyan
foreach ($vm in $vms) {
    $nicId = az vm show --resource-group $ResourceGroupName --name $vm --query "networkProfile.networkInterfaces[0].id" -o tsv 2>$null
    if ($nicId) {
        $nicName = ($nicId -split '/')[-1]
        $existingPipId = az network nic show --ids $nicId --query "ipConfigurations[0].publicIPAddress.id" -o tsv 2>$null
        if (-not $existingPipId) {
            if ($nicName -match '(.+)-nic-(\d+)-(.+)') {
                $prefix = $matches[1]
                $index = $matches[2]
                $suffix = $matches[3]
                $pipName = "$prefix-pip-$index-$suffix"
            } else {
                $pipName = "$nicName-pip"
            }
            $existingPip = az network public-ip show `
                --resource-group $ResourceGroupName `
                --name $pipName `
                --query "id" -o tsv 2>$null
            $pipId = $null
            $actionMsg = ""
            if ($existingPip) {
                $pipId = $existingPip
                $actionMsg = "Re-associating existing Public IP ($pipName) to $vm..."
            } else {
                $pipId = az network public-ip create `
                    --resource-group $ResourceGroupName `
                    --name $pipName `
                    --sku Standard `
                    --allocation-method Static `
                    --version IPv4 `
                    --query "publicIp.id" -o tsv 2>$null
                $actionMsg = "Creating Public IP ($pipName) for $vm..."
            }
            Write-Host "$actionMsg" -NoNewline
            $assocResult = $null
            if ($pipId) {
                $assocResult = az network nic ip-config update `
                    --resource-group $ResourceGroupName `
                    --nic-name $nicName `
                    --name ipconfig1 `
                    --public-ip-address $pipId 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host " Success" -ForegroundColor Green
                } else {
                    Write-Host " Failed" -ForegroundColor Red
                    Write-Host "    $assocResult" -ForegroundColor Red
                }
            } else {
                Write-Host " Failed (no Public IP ID)" -ForegroundColor Red
            }
        } else {
            $existingPipName = ($existingPipId -split '/')[-1]
            Write-Host "Public IP ($existingPipName) already associated with $vm" -ForegroundColor Gray
        }
    }
}
Write-Host ""
Write-Host "Public IPs allocated." -ForegroundColor Green
Write-Host ""

# Start each VM

foreach ($vm in $vms) {
    Write-Host "Starting $vm..." -NoNewline
    $startOutput = az vm start --resource-group $ResourceGroupName --name $vm --no-wait 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " Success" -ForegroundColor Green
    } else {
        Write-Host " Failed" -ForegroundColor Red
        Write-Host "    $startOutput" -ForegroundColor Red
    }
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
    Write-Host "To check VM status (including power state):" -ForegroundColor Cyan
    Write-Host "  az vm list --resource-group $ResourceGroupName --show-details --query '[].{Name:name, PowerState:powerState}' -o table"
}
