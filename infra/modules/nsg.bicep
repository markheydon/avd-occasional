// ===================================
// Network Security Group Module
// Simple configuration for personal desktop use
// Blocks all inbound, allows all outbound
// ===================================

param nsgName string
param location string
param tags object

// ===================================
// Resources
// ===================================

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      // ===================================
      // INBOUND RULES
      // ===================================
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4096
          direction: 'Inbound'
          description: 'Block all inbound - AVD uses reverse connections'
        }
      }
      // ===================================
      // OUTBOUND RULES
      // ===================================
      {
        name: 'AllowAllOutbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
          description: 'Allow all outbound for personal desktop internet access'
        }
      }
    ]
  }
}

// ===================================
// Outputs
// ===================================

@description('Network Security Group ID')
output nsgId string = nsg.id

@description('Network Security Group Name')
output nsgName string = nsg.name
