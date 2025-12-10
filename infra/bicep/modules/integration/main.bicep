// Integration Services Module - Service Bus and Event Grid

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object

@description('Service Bus configuration')
param serviceBusConfig object

@description('Data VNet ID')
param dataVnetId string

@description('Private Endpoint Subnet ID')
param peSubnetId string

@description('Service Bus Private DNS Zone ID')
param serviceBusPrivateDnsZoneId string

@description('Storage Account ID for Event Grid')
param storageAccountId string

// NOTE: Simplified structure - production should use Azure Verified Modules
// - br/public:avm/res/service-bus/namespace
// - br/public:avm/res/event-grid/system-topic

output serviceBusNamespace string = serviceBusConfig.name
output serviceBusFqdn string = '${serviceBusConfig.name}.servicebus.windows.net'
output serviceBusConnectionString string = 'Endpoint=sb://${serviceBusConfig.name}.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=PLACEHOLDER'
output serviceBusQueueName string = serviceBusConfig.queueName
