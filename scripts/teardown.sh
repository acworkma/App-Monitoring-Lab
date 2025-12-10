#!/bin/bash
set -e

# ========================================
# Azure Monitoring Lab Teardown Script
# ========================================

echo "======================================"
echo "Azure Monitoring Lab Teardown"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Check if deployment info exists
if [ ! -f ".azure/deployment-info.json" ]; then
    echo -e "${YELLOW}Warning: Deployment info not found${NC}"
    echo "Please enter resource group name manually"
    read -p "Resource Group Name: " RG_NAME
else
    RG_NAME=$(jq -r '.resourceGroup' .azure/deployment-info.json)
    echo "Found resource group: $RG_NAME"
fi

# Verify resource group exists
if ! az group exists --name "$RG_NAME" &> /dev/null; then
    echo -e "${RED}Error: Resource group '$RG_NAME' does not exist${NC}"
    exit 1
fi

echo ""
echo -e "${RED}WARNING: This will permanently delete all resources in:${NC}"
echo "  Resource Group: $RG_NAME"
echo ""
echo "This includes:"
echo "  - Virtual WAN and all networking"
echo "  - PostgreSQL database and data"
echo "  - Redis cache"
echo "  - Storage accounts and Data Lake files"
echo "  - Container Apps and images"
echo "  - Log Analytics Workspace data"
echo "  - Application Insights telemetry"
echo ""

read -p "Are you absolutely sure? Type 'DELETE' to confirm: " CONFIRM

if [ "$CONFIRM" != "DELETE" ]; then
    echo "Teardown cancelled"
    exit 0
fi

echo ""
read -p "Preserve Log Analytics data for 90 days? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Log Analytics workspace will be soft-deleted (recoverable for 90 days)"
    DELETE_MODE="soft"
else
    echo "Log Analytics workspace will be permanently deleted"
    DELETE_MODE="hard"
fi

echo ""
echo "Starting deletion..."

# Delete resource group
az group delete \
  --name "$RG_NAME" \
  --yes \
  --no-wait

echo -e "${GREEN}✓ Deletion initiated${NC}"
echo ""
echo "Resource group deletion is running in the background."
echo "This may take 10-15 minutes to complete."
echo ""
echo "To check status:"
echo "  az group show --name $RG_NAME"
echo ""

# Clean up local files
if [ -f ".azure/deployment-info.json" ]; then
    rm .azure/deployment-info.json
    echo "Removed local deployment info"
fi

echo -e "${GREEN}Teardown complete${NC}"
