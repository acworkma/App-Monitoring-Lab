// Networking Module - Virtual WAN, VNets, Bastion, Private DNS Zones

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object

@description('Virtual network configurations')
param vnetConfigurations object

@description('Virtual WAN configuration')
param virtualWanConfig object

@description('Azure Bastion configuration')
param bastionConfig object

// ========================================
// Virtual WAN and Hub
// ========================================

resource virtualWan 'Microsoft.Network/virtualWans@2023-05-01' = {
  name: virtualWanConfig.name
  location: location
  tags: tags
  properties: {
    type: 'Standard'
    disableVpnEncryption: false
    allowBranchToBranchTraffic: true
  }
}

resource virtualHub 'Microsoft.Network/virtualHubs@2023-05-01' = {
  name: virtualWanConfig.hubName
  location: location
  tags: tags
  properties: {
    addressPrefix: virtualWanConfig.hubAddressPrefix
    virtualWan: {
      id: virtualWan.id
    }
    sku: 'Standard'
  }
}

// ========================================
// Azure Firewall
// ========================================

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-05-01' = {
  name: '${virtualWanConfig.firewallName}-policy'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
  }
}

resource firewallPolicyRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-05-01' = {
  parent: firewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'AllowAll'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AllowAllTraffic'
            ipProtocols: [
              'Any'
            ]
            sourceAddresses: [
              '*'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-05-01' = {
  name: virtualWanConfig.firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_Hub'
      tier: 'Standard'
    }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
    virtualHub: {
      id: virtualHub.id
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
  dependsOn: [
    firewallPolicyRuleCollectionGroup
  ]
}

// ========================================
// P2S VPN Gateway
// ========================================

resource vpnServerConfiguration 'Microsoft.Network/vpnServerConfigurations@2023-05-01' = {
  name: '${virtualWanConfig.vpnGatewayName}-config'
  location: location
  tags: tags
  properties: {
    vpnProtocols: [
      'OpenVPN'
    ]
    vpnAuthenticationTypes: [
      'AAD'
    ]
    aadAuthenticationParameters: {
      aadTenant: 'https://login.microsoftonline.com/${tenant().tenantId}/'
      aadAudience: '41b23e61-6c1e-4545-b367-cd054e0ed4b4' // Azure VPN Client App ID
      aadIssuer: 'https://sts.windows.net/${tenant().tenantId}/'
    }
  }
}

resource p2sVpnGateway 'Microsoft.Network/p2sVpnGateways@2023-05-01' = {
  name: virtualWanConfig.vpnGatewayName
  location: location
  tags: tags
  properties: {
    virtualHub: {
      id: virtualHub.id
    }
    vpnGatewayScaleUnit: 1
    p2SConnectionConfigurations: [
      {
        name: 'P2SConnectionConfig'
        properties: {
          vpnClientAddressPool: {
            addressPrefixes: [
              virtualWanConfig.vpnClientAddressPool
            ]
          }
          routingConfiguration: {
            associatedRouteTable: {
              id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
            }
            propagatedRouteTables: {
              ids: [
                {
                  id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
                }
              ]
            }
          }
        }
      }
    ]
    vpnServerConfiguration: {
      id: vpnServerConfiguration.id
    }
  }
}

// ========================================
// Data VNet
// ========================================

resource dataVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetConfigurations.dataVnet.name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetConfigurations.dataVnet.addressPrefix
      ]
    }
    subnets: [for subnet in vnetConfigurations.dataVnet.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        delegations: subnet.delegation != null ? [
          {
            name: '${subnet.name}-delegation'
            properties: {
              serviceName: subnet.delegation
            }
          }
        ] : []
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    }]
  }
}

// ========================================
// Ops VNet
// ========================================

resource opsVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetConfigurations.opsVnet.name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetConfigurations.opsVnet.addressPrefix
      ]
    }
    subnets: [for subnet in vnetConfigurations.opsVnet.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        delegations: subnet.delegation != null ? [
          {
            name: '${subnet.name}-delegation'
            properties: {
              serviceName: subnet.delegation
            }
          }
        ] : []
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    }]
  }
}

// ========================================
// VNet Connections to Hub
// ========================================

resource dataVnetConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-05-01' = {
  parent: virtualHub
  name: '${vnetConfigurations.dataVnet.name}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: dataVnet.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
      }
      propagatedRouteTables: {
        ids: [
          {
            id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
          }
        ]
      }
    }
  }
  dependsOn: [
    firewall
  ]
}

resource opsVnetConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-05-01' = {
  parent: virtualHub
  name: '${vnetConfigurations.opsVnet.name}-connection'
  properties: {
    remoteVirtualNetwork: {
      id: opsVnet.id
    }
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
      }
      propagatedRouteTables: {
        ids: [
          {
            id: '${virtualHub.id}/hubRouteTables/defaultRouteTable'
          }
        ]
      }
    }
  }
  dependsOn: [
    firewall
  ]
}

// ========================================
// Private DNS Zones
// ========================================

resource postgresPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

resource redisPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.redis.cache.windows.net'
  location: 'global'
  tags: tags
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource serviceBusPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.servicebus.windows.net'
  location: 'global'
  tags: tags
}

resource storagePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.dfs.core.windows.net'
  location: 'global'
  tags: tags
}

resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
}

// ========================================
// Link Private DNS Zones to VNets
// ========================================

resource postgresDataVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: postgresPrivateDnsZone
  name: 'link-to-data-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: dataVnet.id
    }
    registrationEnabled: false
  }
}

resource postgresOpsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: postgresPrivateDnsZone
  name: 'link-to-ops-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: opsVnet.id
    }
    registrationEnabled: false
  }
}

resource redisDataVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: redisPrivateDnsZone
  name: 'link-to-data-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: dataVnet.id
    }
    registrationEnabled: false
  }
}

resource redisOpsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: redisPrivateDnsZone
  name: 'link-to-ops-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: opsVnet.id
    }
    registrationEnabled: false
  }
}

resource keyVaultDataVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultPrivateDnsZone
  name: 'link-to-data-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: dataVnet.id
    }
    registrationEnabled: false
  }
}

resource keyVaultOpsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: keyVaultPrivateDnsZone
  name: 'link-to-ops-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: opsVnet.id
    }
    registrationEnabled: false
  }
}

resource serviceBusDataVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: serviceBusPrivateDnsZone
  name: 'link-to-data-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: dataVnet.id
    }
    registrationEnabled: false
  }
}

resource serviceBusOpsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: serviceBusPrivateDnsZone
  name: 'link-to-ops-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: opsVnet.id
    }
    registrationEnabled: false
  }
}

resource storageDataVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storagePrivateDnsZone
  name: 'link-to-data-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: dataVnet.id
    }
    registrationEnabled: false
  }
}

resource storageOpsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storagePrivateDnsZone
  name: 'link-to-ops-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: opsVnet.id
    }
    registrationEnabled: false
  }
}

resource acrDataVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZone
  name: 'link-to-data-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: dataVnet.id
    }
    registrationEnabled: false
  }
}

resource acrOpsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: acrPrivateDnsZone
  name: 'link-to-ops-vnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: opsVnet.id
    }
    registrationEnabled: false
  }
}

// ========================================
// Azure Bastion
// ========================================

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${bastionConfig.name}-pip'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: bastionConfig.name
  location: location
  tags: tags
  sku: {
    name: bastionConfig.skuName
  }
  properties: {
    enableTunneling: true
    enableIpConnect: true
    enableKerberos: false
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          subnet: {
            id: '${opsVnet.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

// ========================================
// Outputs
// ========================================

output dataVnetId string = dataVnet.id
output dataVnetName string = dataVnet.name
output opsVnetId string = opsVnet.id
output opsVnetName string = opsVnet.name

output postgresSubnetId string = '${dataVnet.id}/subnets/postgres-snet-01'
output peDataSubnetId string = '${dataVnet.id}/subnets/pe-snet-01'
output acaSubnetId string = '${opsVnet.id}/subnets/aca-snet-01'
output peOpsSubnetId string = '${opsVnet.id}/subnets/pe-ops-snet-01'
output bastionSubnetId string = '${opsVnet.id}/subnets/AzureBastionSubnet'

output virtualWanId string = virtualWan.id
output virtualHubId string = virtualHub.id
output firewallId string = firewall.id
output p2sVpnGatewayId string = p2sVpnGateway.id

output postgresPrivateDnsZoneId string = postgresPrivateDnsZone.id
output redisPrivateDnsZoneId string = redisPrivateDnsZone.id
output keyVaultPrivateDnsZoneId string = keyVaultPrivateDnsZone.id
output serviceBusPrivateDnsZoneId string = serviceBusPrivateDnsZone.id
output storagePrivateDnsZoneId string = storagePrivateDnsZone.id
output acrPrivateDnsZoneId string = acrPrivateDnsZone.id

output bastionId string = bastion.id
output bastionFqdn string = bastion.properties.dnsName
