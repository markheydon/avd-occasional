// ===================================
// Session Host (VM) Module
// Creates AVD session host VMs
// 
// Optimized for occasional use personal desktops:
// - Standard SSD for fast boot/performance (same cost as HDD)
// - Trusted Launch for enhanced security (no extra cost)
// - Automatic Windows Updates via platform orchestration
// - Boot diagnostics enabled for troubleshooting
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

// ===================================
// Resources - Public IP Addresses
// ===================================

resource publicIPs 'Microsoft.Network/publicIPAddresses@2025-01-01' = [for i in range(0, vmCount): {
  name: '${resourcePrefix}-pip-${i}-${uniqueSuffix}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    deleteOption: 'Delete'
  }
}]

// ===================================
// Resources - Network Interfaces
// ===================================

resource networkInterfaces 'Microsoft.Network/networkInterfaces@2025-01-01' = [for i in range(0, vmCount): {
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
          publicIPAddress: {
            id: publicIPs[i].id
          }
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

// Note: Windows computer names have a maximum length of 15 characters,
// so we truncate the unique suffix to ensure compliance.
var computerNames = [for i in range(0, vmCount): toLower(substring('${vmNamePrefix}-${i}-${uniqueSuffix}', 0, 15))]
resource vmResources 'Microsoft.Compute/virtualMachines@2025-04-01' = [for i in range(0, vmCount): {
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
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    osProfile: {
      computerName: computerNames[i]
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
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
          storageAccountType: 'StandardSSD_LRS'
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
        enabled: true
      }
    }
  }
}]


// ===================================
// Extensions - AAD Join (Entra ID)
// ===================================

resource aadLoginExtension 'Microsoft.Compute/virtualMachines/extensions@2025-04-01' = [for i in range(0, vmCount): {
  parent: vmResources[i]
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
  }
}]

// ===================================
// Extensions - Join VM to AVD Host Pool
// ===================================

resource avdJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2025-04-01' = [for i in range(0, vmCount): {
  parent: vmResources[i]
  name: '${vmNamePrefix}-${i}-AddSessionHost'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    settings: {
      modulesUrl: artifactsLocation
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPoolName
        aadJoin: true
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: hostPoolToken
      }
    }
  }
  dependsOn: [
    aadLoginExtension[i]
  ]
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

@description('Public IP Address IDs')
output publicIPIds array = [for i in range(0, vmCount): publicIPs[i].id]

@description('Public IP Address Names')
output publicIPNames array = [for i in range(0, vmCount): publicIPs[i].name]
