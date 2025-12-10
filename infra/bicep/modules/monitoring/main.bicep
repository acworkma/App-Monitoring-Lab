// Monitoring Module - Log Analytics and Application Insights

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object

@description('Log Analytics configuration')
param logAnalyticsConfig object

@description('Application Insights configuration')
param appInsightsConfig object

// ========================================
// Log Analytics Workspace
// ========================================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsConfig.name
  location: location
  tags: tags
  properties: {
    sku: {
      name: logAnalyticsConfig.skuName
    }
    retentionInDays: logAnalyticsConfig.retentionInDays
    workspaceCapping: {
      dailyQuotaGb: logAnalyticsConfig.dailyQuotaGb
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ========================================
// Application Insights
// ========================================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsConfig.name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: appInsightsConfig.applicationType
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    SamplingPercentage: appInsightsConfig.samplingPercentage
  }
}

// ========================================
// Outputs
// ========================================

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsCustomerId string = logAnalyticsWorkspace.properties.customerId
output logAnalyticsSharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey

output appInsightsId string = appInsights.id
output appInsightsName string = appInsights.name
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output appInsightsConnectionString string = appInsights.properties.ConnectionString
