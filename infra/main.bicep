// ===================================
// Azure Virtual Desktop - Main Template
// Personal Desktop for Occasional Use
// ===================================

targetScope = 'resourceGroup'

// ===================================
// Parameters
// ===================================

@description('Environment name for resource naming')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Workload size - controls VM SKU selection')
@allowed(['light', 'moderate'])
param workloadSize string = 'moderate'

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Number of session hosts to deploy')
@minValue(1)
@maxValue(5)
param vmCount int = 1

@description('Admin username for session hosts')
param adminUsername string = 'avdadmin'

@description('Admin password for session hosts')
@secure()
param adminPassword string

@description('Tags for cost tracking and resource management')
param tags object = {
  environment: environment
  project: 'avd-occasional'
  createdDate: utcNow('yyyy-MM-dd')
  managedBy: 'bicep'
}

@description('AVD artifacts location (DSC configuration)')
param artifactsLocation string

// ===================================
// Variables
// ===================================

var resourcePrefix = 'avd-${environment}'
var uniqueSuffix = uniqueString(resourceGroup().id)

// SKU mapping based on workload size
var vmSkuMap = {
  light: 'Standard_B2s'
  moderate: 'Standard_D2s_v3'
}
var vmSku = vmSkuMap[workloadSize]

// Windows 11 Enterprise multi-session image
var vmImageReference = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'Windows-11'
  sku: 'win11-23h2-ent'
  version: 'latest'
}

var vnetName = '${resourcePrefix}-vnet-${uniqueSuffix}'
var subnetName = 'avd-hosts'
var hostPoolName = '${resourcePrefix}-hp-${uniqueSuffix}'
var workspaceName = '${resourcePrefix}-ws-${uniqueSuffix}'
var appGroupName = '${resourcePrefix}-dag-${uniqueSuffix}'
var nsgName = '${resourcePrefix}-nsg-${uniqueSuffix}'

// Generate host pool registration token (valid for 24 hours)
var hostPoolToken = avdPoolModule.outputs.registrationToken

// ===================================
// Modules - Network Infrastructure
// ===================================

module networkModule 'modules/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    vnetName: vnetName
    subnetName: subnetName
    location: location
    tags: tags
  }
}

module nsgModule 'modules/nsg.bicep' = {
  name: 'nsg-deployment'
  params: {
    nsgName: nsgName
    location: location
    tags: tags
  }
}

// ===================================
// Modules - AVD Infrastructure
// ===================================

module avdPoolModule 'modules/avd-pool.bicep' = {
  name: 'avd-pool-deployment'
  params: {
    hostPoolName: hostPoolName
    workspaceName: workspaceName
    appGroupName: appGroupName
    location: location
    tags: tags
  }
  dependsOn: [
    networkModule
  ]
}

// ===================================
// Modules - Session Hosts (VMs)
// ===================================

module sessionHostModule 'modules/session-host.bicep' = {
  name: 'session-host-deployment'
  params: {
    resourcePrefix: resourcePrefix
    vmCount: vmCount
    vmSku: vmSku
    vmImageReference: vmImageReference
    subnetId: networkModule.outputs.subnetId
    nsgId: nsgModule.outputs.nsgId
    location: location
    adminUsername: adminUsername
    adminPassword: adminPassword
    tags: tags
    artifactsLocation: artifactsLocation
    hostPoolToken: hostPoolToken
    hostPoolName: hostPoolName
  }
}

// ===================================
// Outputs
// ===================================

@description('Resource group name')
output resourceGroupName string = resourceGroup().name

@description('Virtual Network ID')
output vnetId string = networkModule.outputs.vnetId

@description('AVD Host Pool ID')
output hostPoolId string = avdPoolModule.outputs.hostPoolId

@description('AVD Workspace ID')
output workspaceId string = avdPoolModule.outputs.workspaceId

@description('AVD Application Group ID')
output appGroupId string = avdPoolModule.outputs.appGroupId

@description('Session Host VM IDs')
output sessionHostIds array = sessionHostModule.outputs.vmIds

@description('Session Host Names')
output sessionHostNames array = sessionHostModule.outputs.vmNames

@description('VM SKU used')
output vmSkuUsed string = vmSku

@description('Total estimated monthly cost (VM deallocated)')
output estimatedMonthlyCostIdle string = vmSku == 'Standard_B2s' ? '~£10-12' : '~£10-15'

@description('Total estimated monthly cost (VM running)')
output estimatedMonthlyCostActive string = vmSku == 'Standard_B2s' ? '~£35-40' : '~£90-120'
