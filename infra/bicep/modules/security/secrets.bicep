// Secrets Module - Store connection strings in Key Vault

@description('Key Vault name')
param keyVaultName string

@description('PostgreSQL connection string')
@secure()
param postgresConnectionString string

@description('Redis access key')
@secure()
param redisAccessKey string

@description('Redis SSL host')
param redisSslHost string

@description('Service Bus connection string')
@secure()
param serviceBusConnectionString string

@description('Storage connection string')
@secure()
param storageConnectionString string

@description('Application Insights connection string')
@secure()
param appInsightsConnectionString string

@description('ACR login server')
param acrLoginServer string

@description('ACR username')
param acrUsername string

@description('ACR password')
@secure()
param acrPassword string

// Reference existing Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

// Store secrets
resource postgresSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'postgresql-connection-string'
  properties: {
    value: postgresConnectionString
  }
}

resource redisKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'redis-access-key'
  properties: {
    value: redisAccessKey
  }
}

resource redisHostSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'redis-host'
  properties: {
    value: redisSslHost
  }
}

resource serviceBusSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'servicebus-connection-string'
  properties: {
    value: serviceBusConnectionString
  }
}

resource storageSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'storage-connection-string'
  properties: {
    value: storageConnectionString
  }
}

resource appInsightsSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'applicationinsights-connection-string'
  properties: {
    value: appInsightsConnectionString
  }
}

resource acrServerSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'acr-login-server'
  properties: {
    value: acrLoginServer
  }
}

resource acrUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'acr-username'
  properties: {
    value: acrUsername
  }
}

resource acrPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: keyVault
  name: 'acr-password'
  properties: {
    value: acrPassword
  }
}

output secretsStored bool = true
