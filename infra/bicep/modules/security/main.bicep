// Security Module - Key Vault and Managed Identity

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object

@description('Key Vault configuration')
param keyVaultConfig object

@description('Ops VNet ID')
param opsVnetId string

@description('Private Endpoint Subnet ID')
param peSubnetId string

@description('Key Vault Private DNS Zone ID')
param privateDnsZoneId string

// ========================================
// Managed Identity
// ========================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-${keyVaultConfig.name}'
  location: location
  tags: tags
}

// ========================================
// Key Vault
// ========================================

resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: keyVaultConfig.name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: keyVaultConfig.skuName
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: keyVaultConfig.enableRbacAuthorization
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// ========================================
// Private Endpoint for Key Vault
// ========================================

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${keyVault.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: peSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVault.name}-pe-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

// ========================================
// Role Assignment - Managed Identity as Key Vault Secrets User
// ========================================

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource managedIdentityKeyVaultRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentity.id, keyVaultSecretsUserRoleId)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ========================================
// Outputs
// ========================================

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri

output managedIdentityId string = managedIdentity.id
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
