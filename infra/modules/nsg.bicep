// ===================================
// Network Security Group Module
// Minimal rules for AVD reverse connections
// ===================================

param nsgName string
param location string
param tags object

// ===================================
// Resources
// ===================================

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowOutboundHttps'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
          description: 'Allow HTTPS outbound for Azure Virtual Desktop service communication'
        }
      }
      {
        name: 'AllowOutboundDns'
        properties: {
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
          description: 'Allow DNS queries outbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
          description: 'Deny all inbound traffic (AVD uses reverse connections)'
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
