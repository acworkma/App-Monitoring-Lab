targetScope = 'subscription'

// ========================================
// Parameters
// ========================================

@description('Location for all resources')
param location string

@description('Naming prefix for resources')
param prefix string

@description('Environment name')
param environment string

@description('Tags for all resources')
param tags object

@description('Virtual network configurations')
param vnetConfigurations object

@description('Virtual WAN configuration')
param virtualWanConfig object

@description('PostgreSQL configuration')
param postgresConfig object

@description('Redis configuration')
param redisConfig object

@description('Storage configuration')
param storageConfig object

@description('Service Bus configuration')
param serviceBusConfig object

@description('Key Vault configuration')
param keyVaultConfig object

@description('Container Registry configuration')
param acrConfig object

@description('Log Analytics configuration')
param logAnalyticsConfig object

@description('Application Insights configuration')
param appInsightsConfig object

@description('Container App Environment configuration')
param containerAppEnvConfig object

@description('Azure Bastion configuration')
param bastionConfig object

@description('Azure Load Testing configuration')
param loadTestConfig object

// ========================================
// Variables
// ========================================

var resourceGroupName = 'rg-${prefix}-${location}'

// ========================================
// Resource Group
// ========================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ========================================
// Networking Module
// ========================================

module networking 'modules/networking/main.bicep' = {
  name: 'networking-deployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    vnetConfigurations: vnetConfigurations
    virtualWanConfig: virtualWanConfig
    bastionConfig: bastionConfig
  }
}

// ========================================
// Monitoring Module
// ========================================

module monitoring 'modules/monitoring/main.bicep' = {
  name: 'monitoring-deployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    logAnalyticsConfig: logAnalyticsConfig
    appInsightsConfig: appInsightsConfig
  }
}

// ========================================
// Security Module (Key Vault + Managed Identity)
// ========================================

module security 'modules/security/main.bicep' = {
  name: 'security-deployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    keyVaultConfig: keyVaultConfig
    opsVnetId: networking.outputs.opsVnetId
    peSubnetId: networking.outputs.peOpsSubnetId
    privateDnsZoneId: networking.outputs.keyVaultPrivateDnsZoneId
  }
}

// ========================================
// Container Registry Module
// ========================================

module acr 'modules/compute/acr.bicep' = {
  name: 'acr-deployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    acrConfig: acrConfig
    opsVnetId: networking.outputs.opsVnetId
    peSubnetId: networking.outputs.peOpsSubnetId
    privateDnsZoneId: networking.outputs.acrPrivateDnsZoneId
  }
}

// ========================================
// Data Services Module
// ========================================

module dataServices 'modules/data/main.bicep' = {
  name: 'data-services-deployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    postgresConfig: postgresConfig
    redisConfig: redisConfig
    storageConfig: storageConfig
    dataVnetId: networking.outputs.dataVnetId
    postgresSubnetId: networking.outputs.postgresSubnetId
    peSubnetId: networking.outputs.peDataSubnetId
    postgresPrivateDnsZoneId: networking.outputs.postgresPrivateDnsZoneId
    redisPrivateDnsZoneId: networking.outputs.redisPrivateDnsZoneId
    storagePrivateDnsZoneId: networking.outputs.storagePrivateDnsZoneId
  }
}

// ========================================
// Integration Services Module
// ========================================

module integration 'modules/integration/main.bicep' = {
  name: 'integration-services-deployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    serviceBusConfig: serviceBusConfig
    dataVnetId: networking.outputs.dataVnetId
    peSubnetId: networking.outputs.peDataSubnetId
    serviceBusPrivateDnsZoneId: networking.outputs.serviceBusPrivateDnsZoneId
    storageAccountId: dataServices.outputs.storageAccountId
  }
}

// ========================================
// Container App Environment Module
// ========================================

module containerAppEnv 'modules/compute/containerAppEnvironment.bicep' = {
  name: 'container-app-env-deployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    containerAppEnvConfig: containerAppEnvConfig
    acaSubnetId: networking.outputs.acaSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

// ========================================
// Azure Load Testing Module
// ========================================

module loadTesting 'modules/testing/loadTesting.bicep' = {
  name: 'load-testing-deployment'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    loadTestConfig: loadTestConfig
  }
}

// ========================================
// Store Secrets in Key Vault
// ========================================

module secrets 'modules/security/secrets.bicep' = {
  name: 'secrets-deployment'
  scope: resourceGroup
  params: {
    keyVaultName: security.outputs.keyVaultName
    postgresConnectionString: dataServices.outputs.postgresConnectionString
    redisAccessKey: dataServices.outputs.redisAccessKey
    redisSslHost: dataServices.outputs.redisSslHost
    serviceBusConnectionString: integration.outputs.serviceBusConnectionString
    storageConnectionString: dataServices.outputs.storageConnectionString
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    acrLoginServer: acr.outputs.acrLoginServer
    acrUsername: acr.outputs.acrUsername
    acrPassword: acr.outputs.acrPassword
  }
  dependsOn: [
    security
    dataServices
    integration
    monitoring
    acr
  ]
}

// ========================================
// Outputs
// ========================================

output resourceGroupName string = resourceGroupName
output location string = location

// Networking Outputs
output dataVnetId string = networking.outputs.dataVnetId
output opsVnetId string = networking.outputs.opsVnetId
output bastionFqdn string = networking.outputs.bastionFqdn

// Monitoring Outputs
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsWorkspaceId
output appInsightsId string = monitoring.outputs.appInsightsId
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

// Security Outputs
output keyVaultName string = security.outputs.keyVaultName
output managedIdentityId string = security.outputs.managedIdentityId
output managedIdentityClientId string = security.outputs.managedIdentityClientId

// Container Registry Outputs
output acrName string = acr.outputs.acrName
output acrLoginServer string = acr.outputs.acrLoginServer

// Data Services Outputs
output postgresServerName string = dataServices.outputs.postgresServerName
output postgresFqdn string = dataServices.outputs.postgresFqdn
output redisName string = dataServices.outputs.redisName
output redisHostName string = dataServices.outputs.redisHostName
output storageAccountName string = dataServices.outputs.storageAccountName

// Integration Services Outputs
output serviceBusNamespace string = integration.outputs.serviceBusNamespace
output serviceBusFqdn string = integration.outputs.serviceBusFqdn
output serviceBusQueueName string = integration.outputs.serviceBusQueueName

// Container Apps Outputs
output containerAppEnvId string = containerAppEnv.outputs.containerAppEnvId
output containerAppEnvName string = containerAppEnv.outputs.containerAppEnvName
output containerAppEnvDefaultDomain string = containerAppEnv.outputs.containerAppEnvDefaultDomain

// Load Testing Outputs
output loadTestingName string = loadTesting.outputs.loadTestingName
