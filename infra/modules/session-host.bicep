// ===================================
// Session Host (VM) Module
// Creates AVD session host VMs
// ===================================

param resourcePrefix string
param vmCount int
param vmSku string
param vmImageReference object
param subnetId string
param nsgId string
param location string
param tags object
param adminUsername string
@secure()
param adminPassword string
param artifactsLocation string

@description('Host Pool Name')
param hostPoolName string

@description('Host Pool Registration Token')
@secure()
param hostPoolToken string

// ===================================
// Variables
// ===================================

var vmNamePrefix = '${resourcePrefix}-vm'
var nicNamePrefix = '${resourcePrefix}-nic'
var osDiskNamePrefix = '${resourcePrefix}-osdisk'
var uniqueSuffix = uniqueString(resourceGroup().id)
var avdInstallCommand = 'powershell -Command "& {$downloadPath = \'C:\\temp\'; $agentMsi = Join-Path $downloadPath \'AVDAgent.msi\'; $loaderMsi = Join-Path $downloadPath \'AVDBootLoader.msi\'; $web = New-Object System.Net.WebClient; Write-Host \'Installing AVD Agent...\'; $web.DownloadFile(\'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv\', $agentMsi); Start-Process -FilePath msiexec.exe -ArgumentList \'/i $agentMsi /quiet /norestart\' -Wait; Write-Host \'Installing AVD BootLoader...\'; $web.DownloadFile(\'https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH\', $loaderMsi); Start-Process -FilePath msiexec.exe -ArgumentList \'/i $loaderMsi /quiet /norestart\' -Wait; Remove-Item -Path $agentMsi -Force -ErrorAction SilentlyContinue; Remove-Item -Path $loaderMsi -Force -ErrorAction SilentlyContinue; Write-Host \'AVD installation complete.\'}"'

// ===================================
// Resources - Network Interfaces
// ===================================

resource networkInterfaces 'Microsoft.Network/networkInterfaces@2024-01-01' = [for i in range(0, vmCount): {
  name: '${nicNamePrefix}-${i}-${uniqueSuffix}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          primary: true
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgId
    }
  }
}]

// ===================================
// Resources - Session Host VMs
// ===================================

resource vmResources 'Microsoft.Compute/virtualMachines@2024-03-01' = [for i in range(0, vmCount): {
  name: '${vmNamePrefix}-${i}-${uniqueSuffix}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSku
    }
    osProfile: {
      computerName: '${vmNamePrefix}-${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          enableHotpatching: false
        }
        timeZone: 'UTC'
      }
      allowExtensionOperations: true
    }
    storageProfile: {
      imageReference: vmImageReference
      osDisk: {
        name: '${osDiskNamePrefix}-${i}-${uniqueSuffix}'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaces[i].id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}]

// ===================================
// Extensions - AVD Agent & Boot Loader Installation
// ===================================

resource avdExtension 'Microsoft.Compute/virtualMachines/extensions@2025-04-01' = [for i in range(0, vmCount): {
  parent: vmResources[i]
  name: 'AVDInstall'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: avdInstallCommand
    }
  }
  dependsOn: [
    vmResources
  ]
}]

// ===================================
// Extensions - AAD Join (Entra ID)
// ===================================

resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = [for i in range(0, vmCount): {
  parent: vmResources[i]
  name: 'AADLoginForWindows'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
  }
  dependsOn: [
    vmResources
  ]
}]

// ===================================
// Extensions - Join VM to AVD Host Pool
// ===================================
resource avdJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2025-04-01' = [for i in range(0, vmCount): {
  parent: vmResources[i]
  name: '${vmNamePrefix}-${i}-AddSessionHost'
  location: location
  tags: tags
  dependsOn: [
    aadLoginExtension[i]
    avdExtension[i]
  ]
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: artifactsLocation
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPoolName
        registrationInfoToken: hostPoolToken
        aadJoin: true
      }
    }
  }
}]

// ===================================
// Outputs
// ===================================

@description('Virtual Machine IDs')
output vmIds array = [for i in range(0, vmCount): vmResources[i].id]

@description('Virtual Machine Names')
output vmNames array = [for i in range(0, vmCount): vmResources[i].name]

@description('Network Interface IDs')
output nicIds array = [for i in range(0, vmCount): networkInterfaces[i].id]

@description('VM SKU')
output vmSku string = vmSku

@description('Number of VMs deployed')
output vmCount int = vmCount
