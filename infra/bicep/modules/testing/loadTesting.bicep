// Azure Load Testing Module

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object

@description('Load Testing configuration')
param loadTestConfig object

// NOTE: Simplified - production deployment would create actual resource

output loadTestingName string = loadTestConfig.name
output loadTestingId string = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.LoadTestService/loadTests/${loadTestConfig.name}'
