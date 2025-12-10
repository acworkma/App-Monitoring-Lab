# Azure Monitoring Lab - Quick Reference

## 🚀 Quick Start Commands

### Initial Deployment

```bash
# Login to Azure
az login
az account set --subscription "<your-subscription-id>"

# Deploy infrastructure
chmod +x scripts/deploy.sh
./scripts/deploy.sh

# Wait 45-60 minutes for deployment to complete
```

### Build and Deploy Applications

```bash
# Build Java API
cd apps/api
mvn clean package -DskipTests

# Build Docker image
docker build -t <acr-name>.azurecr.io/api:latest .

# Push to ACR
az acr login --name <acr-name>
docker push <acr-name>.azurecr.io/api:latest
```

### Access Resources

```bash
# Get resource info
RG_NAME="rg-monitoring-lab-canadacentral"

# Application Insights
az monitor app-insights component show \
  --app appi-monitoring-lab-01 \
  --resource-group $RG_NAME

# Key Vault secrets
az keyvault secret list --vault-name <kv-name>

# Container Apps
az containerapp list --resource-group $RG_NAME --output table
```

### View Application Insights Data

```bash
# Recent requests
az monitor app-insights query \
  --app appi-monitoring-lab-01 \
  --resource-group $RG_NAME \
  --analytics-query "requests | top 10 by timestamp desc"

# Exceptions
az monitor app-insights query \
  --app appi-monitoring-lab-01 \
  --resource-group $RG_NAME \
  --analytics-query "exceptions | summarize count() by problemId"

# Custom events
az monitor app-insights query \
  --app appi-monitoring-lab-01 \
  --resource-group $RG_NAME \
  --analytics-query "customEvents | where name == 'ProductViewed' | project timestamp, name"
```

### Cleanup

```bash
chmod +x scripts/teardown.sh
./scripts/teardown.sh
```

## 📋 Key Endpoints

- **Resource Group**: `rg-monitoring-lab-canadacentral`
- **Key Vault**: `kv-monitoring-lab-<unique>`
- **ACR**: `acrmonitoringlab<unique>.azurecr.io`
- **Application Insights**: `appi-monitoring-lab-01`

## 🔑 Environment Variables (for local development)

```bash
export SPRING_DATASOURCE_URL="jdbc:postgresql://<server>.postgres.database.azure.com:5432/labdb"
export SPRING_DATASOURCE_USERNAME="labadmin"
export SPRING_DATASOURCE_PASSWORD="<from-keyvault>"
export SPRING_REDIS_HOST="<redis-name>.redis.cache.windows.net"
export SPRING_REDIS_PASSWORD="<from-keyvault>"
export AZURE_SERVICEBUS_CONNECTION_STRING="<from-keyvault>"
export APPLICATIONINSIGHTS_CONNECTION_STRING="<from-app-insights>"
```

## 📖 Documentation

- **Setup Guide**: [docs/SETUP.md](docs/SETUP.md)
- **Architecture**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Deployment**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- **Implementation Status**: [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md)

## 🛠️ Troubleshooting

### Deployment fails

```bash
# Check deployment status
az deployment sub show --name <deployment-name>

# View deployment logs
az deployment sub show --name <deployment-name> --query properties.error
```

### Container Apps won't start

```bash
# Check logs
az containerapp logs show --name api-ca --resource-group $RG_NAME --follow

# Check environment
az containerapp show --name api-ca --resource-group $RG_NAME
```

### No telemetry in Application Insights

```bash
# Verify connection string is set
az containerapp show --name api-ca --resource-group $RG_NAME \
  --query "properties.template.containers[0].env[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING']"

# Check ingestion delay (2-5 minutes normal)
# View live metrics in Azure Portal for real-time data
```

## 🔗 Useful Links

- [Azure Portal](https://portal.azure.com)
- [Application Insights Documentation](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
