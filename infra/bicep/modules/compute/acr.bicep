// Container Registry Module

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object

@description('ACR configuration')
param acrConfig object

@description('Ops VNet ID')
param opsVnetId string

@description('Private Endpoint Subnet ID')
param peSubnetId string

@description('ACR Private DNS Zone ID')
param privateDnsZoneId string

// NOTE: Production should use br/public:avm/res/container-registry/registry

output acrName string = acrConfig.name
output acrLoginServer string = '${acrConfig.name}.azurecr.io'
output acrUsername string = acrConfig.name
output acrPassword string = 'PLACEHOLDER_ACR_PASSWORD'
