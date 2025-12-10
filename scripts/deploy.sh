#!/bin/bash
set -e

# ========================================
# Azure Monitoring Lab Deployment Script
# ========================================

echo "======================================"
echo "Azure Monitoring Lab Deployment"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

echo -e "${GREEN}✓${NC} Azure CLI found"

# Check if logged in
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged into Azure${NC}"
    echo "Run: az login"
    exit 1
fi

echo -e "${GREEN}✓${NC} Logged into Azure"

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo ""
echo -e "${YELLOW}Current Subscription:${NC}"
echo "  ID: $SUBSCRIPTION_ID"
echo "  Name: $SUBSCRIPTION_NAME"
echo ""

read -p "Deploy to this subscription? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 1
fi

# Configuration
LOCATION="canadacentral"
DEPLOYMENT_NAME="monitoring-lab-$(date +%Y%m%d-%H%M%S)"

echo ""
echo "======================================"
echo "Deployment Configuration"
echo "======================================"
echo "Location: $LOCATION"
echo "Deployment Name: $DEPLOYMENT_NAME"
echo ""

# Start deployment
echo "Starting Bicep deployment..."
echo "This will take approximately 45-60 minutes"
echo ""

DEPLOYMENT_OUTPUT=$(az deployment sub create \
  --name "$DEPLOYMENT_NAME" \
  --location "$LOCATION" \
  --template-file infra/bicep/main.bicep \
  --parameters infra/bicep/parameters/canadacentral.bicepparam \
  --output json)

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Deployment completed successfully${NC}"
echo ""

# Extract outputs
RG_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.resourceGroupName.value')
KV_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.keyVaultName.value')
ACR_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.acrName.value')
ACR_LOGIN_SERVER=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.acrLoginServer.value')
APPINSIGHTS_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.appInsightsId.value' | awk -F'/' '{print $NF}')

echo "======================================"
echo "Deployment Summary"
echo "======================================"
echo "Resource Group: $RG_NAME"
echo "Key Vault: $KV_NAME"
echo "Container Registry: $ACR_NAME"
echo "Application Insights: $APPINSIGHTS_NAME"
echo ""

# Save deployment info
cat > .azure/deployment-info.json <<EOF
{
  "deploymentName": "$DEPLOYMENT_NAME",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "resourceGroup": "$RG_NAME",
  "location": "$LOCATION",
  "keyVault": "$KV_NAME",
  "containerRegistry": "$ACR_NAME",
  "acrLoginServer": "$ACR_LOGIN_SERVER",
  "applicationInsights": "$APPINSIGHTS_NAME",
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo -e "${GREEN}Deployment information saved to .azure/deployment-info.json${NC}"
echo ""

# Next steps
echo "======================================"
echo "Next Steps"
echo "======================================"
echo ""
echo "1. Build and push container images:"
echo "   ./scripts/build-apps.sh"
echo ""
echo "2. Deploy container apps (coming soon in implementation)"
echo ""
echo "3. Configure VPN client:"
echo "   See docs/SETUP.md for instructions"
echo ""
echo "4. Access Application Insights:"
echo "   az portal monitoring component show --name $APPINSIGHTS_NAME --resource-group $RG_NAME"
echo ""
echo -e "${GREEN}Deployment complete!${NC}"
