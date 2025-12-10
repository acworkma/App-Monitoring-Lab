# Deployment Guide

Complete guide for deploying the Azure Monitoring Lab via GitHub Actions or manual deployment.

## Table of Contents

- [Prerequisites](#prerequisites)
- [GitHub Actions Setup](#github-actions-setup)
- [Manual Deployment](#manual-deployment)
- [Application Deployment](#application-deployment)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

1. **Azure CLI** (v2.50.0+)
   ```bash
   az --version
   # Install/upgrade: https://learn.microsoft.com/cli/azure/install-azure-cli
   ```

2. **Git**
   ```bash
   git --version
   ```

3. **Maven** (for local Java builds)
   ```bash
   mvn --version
   # Version 3.8.0+ required
   ```

4. **Docker** (optional, for local container builds)
   ```bash
   docker --version
   ```

### Azure Permissions

Your Azure account must have:
- **Subscription-level permissions**: `Owner` or `Contributor` + `User Access Administrator`
- **Azure AD permissions**: Ability to create service principals (for GitHub Actions)

### Resource Quotas

Verify your subscription has sufficient quotas:
```bash
# Check regional quotas
az vm list-usage --location canadacentral --output table

# Key quotas needed:
# - Standard Dv4 Family vCPUs: 16+ (for Container Apps, PostgreSQL)
# - Public IP Addresses: 3+ (Bastion, VPN Gateway, Firewall)
# - Virtual Networks: 3+
# - Load Balancers: 5+
```

## GitHub Actions Setup

### 1. Fork Repository

Fork this repository to your GitHub account:
```
https://github.com/acworkma/App-Monitoring-Lab → Fork
```

### 2. Create Azure Service Principal with OIDC

Azure recommends **OpenID Connect (OIDC)** for GitHub Actions authentication (no secret rotation needed).

**Step 1: Create App Registration**

```bash
# Set variables
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
APP_NAME="gh-monitoring-lab"

# Create app registration
az ad app create --display-name $APP_NAME --query appId -o tsv
APP_ID=$(az ad app list --display-name $APP_NAME --query [0].appId -o tsv)

# Create service principal
az ad sp create --id $APP_ID
OBJECT_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query [0].id -o tsv)

# Assign Contributor role at subscription level
az role assignment create \
  --role "Contributor" \
  --assignee $APP_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID

# Assign User Access Administrator (for managed identity role assignments)
az role assignment create \
  --role "User Access Administrator" \
  --assignee $APP_ID \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

**Step 2: Configure Federated Credential**

```bash
REPO_OWNER="<your-github-username>"  # e.g., "acworkma"
REPO_NAME="App-Monitoring-Lab"

# Create federated credential for main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "gh-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$REPO_OWNER'/'$REPO_NAME':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions - main branch"
  }'

# Optional: Create federated credential for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "gh-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$REPO_OWNER'/'$REPO_NAME':pull_request",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions - pull requests"
  }'
```

### 3. Configure GitHub Repository Secrets

Navigate to your forked repository:
```
Settings → Secrets and variables → Actions → New repository secret
```

**Required Secrets**:

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `AZURE_CLIENT_ID` | Application (client) ID | `echo $APP_ID` |
| `AZURE_TENANT_ID` | Azure AD tenant ID | `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `az account show --query id -o tsv` |

**No client secret needed with OIDC!**

### 4. Verify Workflow Files

Ensure workflow files exist:
```bash
ls -la .github/workflows/
# Should show:
# - deploy-infra.yml (infrastructure deployment)
# - build-deploy-apps.yml (application build and deploy)
```

### 5. Trigger Deployment

**Option A: Manual Trigger (Recommended for first deployment)**

1. Go to **Actions** tab in GitHub
2. Select **Deploy Infrastructure** workflow
3. Click **Run workflow**
4. Select branch: `main`
5. Click **Run workflow**

**Option B: Automatic Trigger on Push**

```bash
git add .
git commit -m "Initial deployment configuration"
git push origin main
```

This triggers infrastructure deployment automatically.

### 6. Monitor Deployment

1. Navigate to **Actions** tab
2. Click on running workflow
3. Expand jobs to see real-time logs
4. Infrastructure deployment takes **45-60 minutes**

### 7. Deploy Applications

After infrastructure completes:

1. **Actions** → **Build and Deploy Applications**
2. **Run workflow** → **main** branch
3. Deployment takes **15-20 minutes** (Maven build + Docker push + Container Apps update)

## Manual Deployment

### 1. Clone Repository

```bash
git clone https://github.com/acworkma/App-Monitoring-Lab.git
cd App-Monitoring-Lab
```

### 2. Login to Azure

```bash
az login
az account set --subscription "<your-subscription-id>"

# Verify subscription
az account show --output table
```

### 3. Deploy Infrastructure

```bash
# Make script executable
chmod +x scripts/deploy.sh

# Run deployment
./scripts/deploy.sh

# Follow prompts:
# - Confirm subscription
# - Enter unique prefix (e.g., your initials + date)
# - Confirm deployment
```

**Deployment Steps**:
1. Validates prerequisites
2. Creates resource group
3. Deploys Bicep main.bicep (45-60 minutes)
4. Configures secrets in Key Vault
5. Seeds sample data
6. Outputs connection details

### 4. Build and Push Container Images

```bash
# Login to Azure Container Registry
ACR_NAME=$(az deployment group show \
  --resource-group rg-monitoring-lab-canadacentral \
  --name main \
  --query properties.outputs.acrName.value -o tsv)

az acr login --name $ACR_NAME

# Build and push frontend
cd apps/frontend
mvn clean package -DskipTests
docker build -t $ACR_NAME.azurecr.io/frontend:latest .
docker push $ACR_NAME.azurecr.io/frontend:latest

# Build and push API
cd ../api
mvn clean package -DskipTests
docker build -t $ACR_NAME.azurecr.io/api:latest .
docker push $ACR_NAME.azurecr.io/api:latest

# Build and push worker
cd ../worker
mvn clean package -DskipTests
docker build -t $ACR_NAME.azurecr.io/worker:latest .
docker push $ACR_NAME.azurecr.io/worker:latest

cd ../..
```

### 5. Deploy Container Apps

```bash
# Deploy with Bicep
az deployment group create \
  --resource-group rg-monitoring-lab-canadacentral \
  --template-file infra/bicep/modules/compute/containerApps.bicep \
  --parameters @infra/bicep/parameters/canadacentral.bicepparam
```

**Or use Azure CLI directly**:

```bash
RG="rg-monitoring-lab-canadacentral"
CAE="cae-monitoring-lab-01"

# Deploy frontend
az containerapp create \
  --name frontend-ca \
  --resource-group $RG \
  --environment $CAE \
  --image $ACR_NAME.azurecr.io/frontend:latest \
  --registry-server $ACR_NAME.azurecr.io \
  --registry-identity system \
  --target-port 8080 \
  --ingress internal \
  --min-replicas 1 \
  --max-replicas 10 \
  --cpu 1.0 --memory 2.0Gi

# Deploy API
az containerapp create \
  --name api-ca \
  --resource-group $RG \
  --environment $CAE \
  --image $ACR_NAME.azurecr.io/api:latest \
  --registry-server $ACR_NAME.azurecr.io \
  --registry-identity system \
  --target-port 8080 \
  --ingress internal \
  --min-replicas 2 \
  --max-replicas 10 \
  --cpu 1.5 --memory 3.0Gi

# Deploy worker
az containerapp create \
  --name worker-ca \
  --resource-group $RG \
  --environment $CAE \
  --image $ACR_NAME.azurecr.io/worker:latest \
  --registry-server $ACR_NAME.azurecr.io \
  --registry-identity system \
  --min-replicas 1 \
  --max-replicas 5 \
  --cpu 1.0 --memory 2.0Gi
```

## Application Deployment

### Building Locally

**Prerequisites**: Java 21, Maven 3.8+

```bash
# Build all applications
cd apps
mvn clean package -DskipTests

# Run tests
mvn test

# Build with integration tests
mvn clean verify
```

### Running Locally with Application Insights

```bash
# Set Application Insights connection string
export APPLICATIONINSIGHTS_CONNECTION_STRING=$(az monitor app-insights component show \
  --app appi-monitoring-lab-01 \
  --resource-group rg-monitoring-lab-canadacentral \
  --query connectionString -o tsv)

# Run frontend
cd apps/frontend
mvn spring-boot:run

# Run API (in separate terminal)
cd apps/api
export SPRING_DATASOURCE_URL="jdbc:postgresql://psql-monitoring-lab-01.postgres.database.azure.com:5432/labdb?sslmode=require"
export SPRING_DATASOURCE_USERNAME="labadmin"
export SPRING_DATASOURCE_PASSWORD="<password-from-keyvault>"
mvn spring-boot:run

# Run worker (in separate terminal)
cd apps/worker
export AZURE_SERVICEBUS_CONNECTION_STRING="<from-keyvault>"
mvn spring-boot:run
```

### Updating Container Apps

After code changes:

```bash
# Rebuild and push new image
cd apps/api
mvn clean package -DskipTests
docker build -t $ACR_NAME.azurecr.io/api:v2 .
docker push $ACR_NAME.azurecr.io/api:v2

# Update Container App
az containerapp update \
  --name api-ca \
  --resource-group rg-monitoring-lab-canadacentral \
  --image $ACR_NAME.azurecr.io/api:v2

# Monitor revision activation
az containerapp revision list \
  --name api-ca \
  --resource-group rg-monitoring-lab-canadacentral \
  --output table
```

## Verification

### 1. Verify Infrastructure Deployment

```bash
# Check resource group
az group show --name rg-monitoring-lab-canadacentral

# List all resources
az resource list \
  --resource-group rg-monitoring-lab-canadacentral \
  --output table

# Check critical resources
az network vnet list --resource-group rg-monitoring-lab-canadacentral --output table
az postgres flexible-server show --resource-group rg-monitoring-lab-canadacentral --name psql-monitoring-lab-01
az containerapp env show --name cae-monitoring-lab-01 --resource-group rg-monitoring-lab-canadacentral
```

### 2. Verify Container Apps

```bash
# List Container Apps
az containerapp list \
  --resource-group rg-monitoring-lab-canadacentral \
  --output table

# Check app status
az containerapp show \
  --name frontend-ca \
  --resource-group rg-monitoring-lab-canadacentral \
  --query "properties.{Status:provisioningState,Replicas:runningStatus,FQDN:configuration.ingress.fqdn}"

# View logs
az containerapp logs show \
  --name api-ca \
  --resource-group rg-monitoring-lab-canadacentral \
  --follow
```

### 3. Verify Application Insights

```bash
# Check telemetry is flowing
az monitor app-insights query \
  --app appi-monitoring-lab-01 \
  --resource-group rg-monitoring-lab-canadacentral \
  --analytics-query "requests | top 10 by timestamp desc" \
  --output table

# Check for errors
az monitor app-insights query \
  --app appi-monitoring-lab-01 \
  --resource-group rg-monitoring-lab-canadacentral \
  --analytics-query "exceptions | summarize count() by problemId" \
  --output table
```

### 4. Test End-to-End Flow

```bash
# Connect via VPN first (see SETUP.md)

# Get frontend URL
FRONTEND_URL=$(az containerapp show \
  --name frontend-ca \
  --resource-group rg-monitoring-lab-canadacentral \
  --query properties.configuration.ingress.fqdn -o tsv)

# Test frontend (requires VPN connection)
curl -k https://$FRONTEND_URL

# Test API health
API_URL=$(az containerapp show \
  --name api-ca \
  --resource-group rg-monitoring-lab-canadacentral \
  --query properties.configuration.ingress.fqdn -o tsv)

curl -k https://$API_URL/actuator/health
```

### 5. Verify Load Testing

```bash
# List load tests
az load test list --resource-group rg-monitoring-lab-canadacentral

# Get test status
az load test show \
  --name monitoring-lab-test \
  --resource-group rg-monitoring-lab-canadacentral

# Run test manually
az load test run \
  --test-id monitoring-lab-test \
  --resource-group rg-monitoring-lab-canadacentral
```

## Troubleshooting

### Deployment Failures

**Issue**: Bicep deployment fails with quota exceeded

**Solution**:
```bash
# Request quota increase
az vm list-usage --location canadacentral
# Contact Azure support for quota increase
```

**Issue**: Private endpoint DNS resolution fails

**Solution**:
```bash
# Verify Private DNS Zones are created
az network private-dns zone list --resource-group rg-monitoring-lab-canadacentral

# Verify VNet links
az network private-dns link vnet list \
  --resource-group rg-monitoring-lab-canadacentral \
  --zone-name privatelink.postgres.database.azure.com
```

### GitHub Actions Failures

**Issue**: Authentication failed with OIDC

**Solution**:
- Verify federated credential subject matches: `repo:OWNER/REPO:ref:refs/heads/main`
- Check service principal has Contributor role
- Ensure `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` secrets are correct

**Issue**: Workflow cannot find Bicep files

**Solution**:
- Ensure files are committed and pushed to GitHub
- Check workflow paths in `.github/workflows/*.yml`

### Container App Issues

**Issue**: Container App fails to start

**Solution**:
```bash
# Check logs for errors
az containerapp logs show \
  --name api-ca \
  --resource-group rg-monitoring-lab-canadacentral \
  --follow

# Common issues:
# - Image pull failure: Check ACR private endpoint and managed identity AcrPull role
# - Application crash: Check environment variables and health probe configuration
# - Out of memory: Increase memory allocation
```

**Issue**: Cannot reach Container Apps via VPN

**Solution**:
- Verify VPN connection is active
- Check DNS resolution: `nslookup frontend-ca.internal.<env-id>.canadacentral.azurecontainerapps.io`
- Ensure firewall allows traffic from VPN gateway to Container Apps subnet

### Application Insights Issues

**Issue**: No telemetry in Application Insights

**Solution**:
```bash
# Verify connection string is set
az containerapp show \
  --name api-ca \
  --resource-group rg-monitoring-lab-canadacentral \
  --query "properties.template.containers[0].env[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING']"

# Check Application Insights agent logs in container
az containerapp exec \
  --name api-ca \
  --resource-group rg-monitoring-lab-canadacentral \
  --command "cat /tmp/applicationinsights.log"

# Wait 2-5 minutes for telemetry ingestion
```

## Redeployment

To redeploy infrastructure without recreating resources:

```bash
# Infrastructure deployment is idempotent
./scripts/deploy.sh

# Or via GitHub Actions: Re-run workflow
```

Bicep deployments use **incremental mode**, so existing resources are not modified unless their configuration changed.

## Cleanup

To delete all resources:

```bash
chmod +x scripts/teardown.sh
./scripts/teardown.sh

# Or manually:
az group delete --name rg-monitoring-lab-canadacentral --yes --no-wait
```

**Warning**: This deletes all resources and data. Log Analytics data is permanently deleted unless exported.

## Additional Resources

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [GitHub Actions for Azure](https://learn.microsoft.com/azure/developer/github/github-actions)
- [Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Application Insights Java Documentation](https://learn.microsoft.com/azure/azure-monitor/app/java-in-process-agent)
