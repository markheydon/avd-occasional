// ===================================
// Azure Virtual Desktop Pool Module
// Creates Host Pool, Workspace, and Application Group
// ===================================

param hostPoolName string
param workspaceName string
param appGroupName string
param location string
param tags object
@description('Enable validation environment for preview features')
param validationEnvironment bool = false

@description('Token expiration time (default: 30 days from deployment)')
param tokenExpirationTime string = dateTimeAdd(utcNow('u'), 'P30D')

// ===================================
// Resources - Host Pool
// ===================================

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' = {
  name: hostPoolName
  location: location
  tags: tags
  properties: {
    validationEnvironment: validationEnvironment
    hostPoolType: 'Personal'
    personalDesktopAssignmentType: 'Automatic'
    preferredAppGroupType: 'Desktop'
    maxSessionLimit: 1
    loadBalancerType: 'Persistent'
    startVMOnConnect: false
    customRdpProperty: 'targetisaadjoined:i:1;enablerdsaadauth:i:1;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;'
    registrationInfo: {
      expirationTime: tokenExpirationTime
      registrationTokenOperation: 'Update'
    }
  }
}

// ===================================
// Resources - Workspace
// ===================================

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2024-04-03' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    description: 'Occasional use personal desktop workspace'
    friendlyName: 'Personal Desktop'
    publicNetworkAccess: 'Enabled'
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}

// ===================================
// Resources - Application Group (Desktop)
// ===================================

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2024-04-03' = {
  name: appGroupName
  location: location
  tags: tags
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'Desktop'
    description: 'Desktop application group for personal desktop'
    friendlyName: 'Personal Desktop'
  }
}

// ===================================
// Outputs
// ===================================

@description('Host Pool ID')
output hostPoolId string = hostPool.id

@description('Host Pool Name')
output hostPoolName string = hostPool.name

@description('Workspace ID')
output workspaceId string = workspace.id

@description('Workspace Name')
output workspaceName string = workspace.name

@description('Application Group ID')
output appGroupId string = appGroup.id

@description('Application Group Name')
output appGroupName string = appGroup.name

@description('Host Pool registration token')
@secure()
output registrationToken string = hostPool.properties.registrationInfo.token
