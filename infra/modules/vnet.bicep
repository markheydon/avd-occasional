// ===================================
// Virtual Network Module
// Creates VNet with AVD subnet
// 
// Idempotency: This module is idempotent.
// Multiple deployments will create/update the same resources without duplicates.
// Resource names are deterministic, subnet address spaces are fixed,
// and subnets are explicitly defined in the VNet creation.
// ===================================

param vnetName string
param subnetName string
param location string
param tags object

// ===================================
// Variables
// ===================================

var vnetAddressPrefix = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.1.0/24'

// ===================================
// Resources
// ===================================

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          defaultOutboundAccess: false
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [location]
            }
            {
              service: 'Microsoft.KeyVault'
              locations: [location]
            }
            {
              service: 'Microsoft.AzureActiveDirectory'
              locations: ['*']
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ===================================
// Outputs
// ===================================

@description('Virtual Network ID')
output vnetId string = vnet.id

@description('Virtual Network Name')
output vnetName string = vnet.name

@description('Subnet ID')
output subnetId string = '${vnet.id}/subnets/${subnetName}'

@description('Subnet Name')
output subnetName string = subnetName

@description('VNet Address Space')
output vnetAddressSpace string = vnetAddressPrefix

@description('Subnet Address Space')
output subnetAddressSpace string = subnetAddressPrefix
