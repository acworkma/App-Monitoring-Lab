// Container App Environment Module

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object

@description('Container App Environment configuration')
param containerAppEnvConfig object

@description('Container Apps Subnet ID')
param acaSubnetId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Application Insights Connection String')
param appInsightsConnectionString string

// NOTE: Production should use br/public:avm/res/app/managed-environment

output containerAppEnvId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.App/managedEnvironments/${containerAppEnvConfig.name}'
output containerAppEnvName string = containerAppEnvConfig.name
output containerAppEnvDefaultDomain string = '${containerAppEnvConfig.name}.canadacentral.azurecontainerapps.io'
