using '../main.bicep'

// Location parameter
param location = 'canadacentral'

// Naming prefix
param prefix = 'monitoring-lab'

// Environment
param environment = 'lab'

// Tags
param tags = {
  Environment: 'Lab'
  Project: 'App-Monitoring-Lab'
  ManagedBy: 'Bicep'
  Purpose: 'ApplicationInsightsDem o'
}

// Network Configuration
param vnetConfigurations = {
  dataVnet: {
    name: 'data-vnet-01'
    addressPrefix: '10.3.0.0/16'
    subnets: [
      {
        name: 'pe-snet-01'
        addressPrefix: '10.3.0.0/24'
        delegation: null
      }
      {
        name: 'postgres-snet-01'
        addressPrefix: '10.3.1.0/24'
        delegation: 'Microsoft.DBforPostgreSQL/flexibleServers'
      }
    ]
  }
  opsVnet: {
    name: 'ops-vnet-01'
    addressPrefix: '10.5.0.0/16'
    subnets: [
      {
        name: 'aca-snet-01'
        addressPrefix: '10.5.0.0/23'
        delegation: 'Microsoft.App/environments'
      }
      {
        name: 'pe-ops-snet-01'
        addressPrefix: '10.5.2.0/24'
        delegation: null
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.5.3.0/26'
        delegation: null
      }
    ]
  }
}

// Virtual WAN Configuration
param virtualWanConfig = {
  name: 'vwan-${prefix}-01'
  hubName: 'hub-vwanhub-01'
  hubAddressPrefix: '10.4.0.0/16'
  firewallName: 'hub-hubfw-01'
  vpnGatewayName: 'hub-p2sgw-01'
  vpnClientAddressPool: '10.0.2.0/23'
}

// PostgreSQL Configuration
param postgresConfig = {
  name: 'psql-${prefix}-01'
  administratorLogin: 'labadmin'
  skuName: 'Standard_D4ds_v4'
  tier: 'GeneralPurpose'
  storageSizeGB: 128
  version: '15'
  databaseName: 'labdb'
  highAvailability: true
}

// Redis Configuration
param redisConfig = {
  name: 'redis-${prefix}-01'
  skuName: 'Premium'
  skuFamily: 'P'
  skuCapacity: 1
  enableNonSslPort: false
  minimumTlsVersion: '1.2'
}

// Storage Configuration
param storageConfig = {
  name: 'dlstoremonlab01'
  skuName: 'Standard_LRS'
  kind: 'StorageV2'
  isHnsEnabled: true
  containerName: 'uploads'
}

// Service Bus Configuration
param serviceBusConfig = {
  name: 'sbus-${prefix}-01'
  skuName: 'Premium'
  queueName: 'fileprocessing'
}

// Key Vault Configuration
param keyVaultConfig = {
  name: 'kv-monlab-cc01'
  skuName: 'premium'
  enableRbacAuthorization: true
}

// Container Registry Configuration
param acrConfig = {
  name: 'acrmonlabcc01'
  skuName: 'Premium'
  adminUserEnabled: true
}

// Log Analytics Configuration
param logAnalyticsConfig = {
  name: 'law-${prefix}-01'
  skuName: 'PerGB2018'
  retentionInDays: 90
  dailyQuotaGb: 10
}

// Application Insights Configuration
param appInsightsConfig = {
  name: 'appi-${prefix}-01'
  applicationType: 'web'
  samplingPercentage: null  // Adaptive sampling
}

// Container App Environment Configuration
param containerAppEnvConfig = {
  name: 'cae-${prefix}-01'
  workloadProfileName: 'Dedicated-D4'
  zoneRedundant: true
}

// Azure Bastion Configuration
param bastionConfig = {
  name: 'bastion-${prefix}-01'
  skuName: 'Standard'
}

// Azure Load Testing Configuration
param loadTestConfig = {
  name: 'loadtest-${prefix}-01'
}
