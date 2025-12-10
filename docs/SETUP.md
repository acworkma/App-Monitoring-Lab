# Setup Guide

This guide covers setting up access to the Azure Monitoring Lab environment.

## Table of Contents

- [P2S VPN Setup](#p2s-vpn-setup)
- [Azure Bastion Access](#azure-bastion-access)
- [Accessing Application Insights](#accessing-application-insights)
- [Troubleshooting](#troubleshooting)

## P2S VPN Setup

The lab includes a Point-to-Site (P2S) VPN Gateway with Azure AD authentication for secure access to private resources.

### Prerequisites

- Azure VPN Client (Windows, macOS, or Linux)
  - **Windows/macOS**: [Download Azure VPN Client](https://go.microsoft.com/fwlink/?linkid=2117554)
  - **Linux**: Use OpenVPN with Azure AD authentication

### Configuration Steps

1. **Download VPN Configuration**

   After deployment completes, the script outputs a VPN configuration download URL:

   ```bash
   # Or manually download from Azure Portal
   az network vnet-gateway vpn-client generate \
     --resource-group rg-monitoring-lab-canadacentral \
     --name hub-p2sgw-01 \
     --authentication-method EAPTLS
   ```

2. **Import Configuration to Azure VPN Client**

   - Open Azure VPN Client
   - Click **Import** (bottom left)
   - Navigate to downloaded `azurevpnconfig.xml`
   - Click **Import**

3. **Connect to VPN**

   - Select the imported profile: **Monitoring Lab - Canada Central**
   - Click **Connect**
   - Authenticate with your Azure AD credentials
   - Connection establishes within 10-15 seconds

4. **Verify Connectivity**

   ```bash
   # Ping private resources (once connected)
   ping 10.3.1.4  # PostgreSQL private IP
   ping 10.5.0.10 # Container Apps environment
   ```

### VPN Client Address Pool

- **Address Range**: 10.0.2.0/23 (1,024 addresses)
- **DNS**: Azure-provided DNS for private endpoint resolution

## Azure Bastion Access

Azure Bastion provides secure browser-based SSH/RDP access without exposing public IPs.

### Accessing Container Apps via Bastion

Since Container Apps don't have SSH access, use Bastion to connect to the environment for log inspection or troubleshooting:

1. **Navigate to Azure Portal**
   - Go to: [https://portal.azure.com](https://portal.azure.com)
   - Search for **Bastions** or navigate to **ops-vnet-01** → **Bastion**

2. **Connect to Management Resources**

   Bastion is configured in the `ops-vnet-01`. You can use it to connect to any VM deployed in the environment (if needed for management).

   For Container Apps:
   - Use Azure Portal → Container Apps → Console (built-in feature)
   - Or use `az containerapp exec` from your local machine:

   ```bash
   az containerapp exec \
     --name frontend-ca \
     --resource-group rg-monitoring-lab-canadacentral \
     --command /bin/sh
   ```

### Bastion Connection Steps

If you deploy a management VM:

1. Navigate to the VM in Azure Portal
2. Click **Connect** → **Bastion**
3. Enter credentials (or use Azure AD authentication if configured)
4. Click **Connect** - opens browser-based terminal

### Bastion Features

- **Standard SKU**: Supports native client connections (SSH/RDP from local tools)
- **Kerberos Authentication**: Optional for domain-joined VMs
- **Copy/Paste**: Enabled for clipboard operations
- **File Transfer**: Supported for uploading/downloading files

## Accessing Application Insights

### Via Azure Portal

1. **Navigate to Application Insights**
   ```
   Azure Portal → Resource Groups → rg-monitoring-lab-canadacentral → appi-monitoring-lab-01
   ```

2. **Key Features to Explore**

   - **Application Map**: Visual topology of service dependencies
     - Path: Application Insights → Investigate → Application Map
   
   - **Live Metrics Stream**: Real-time telemetry
     - Path: Application Insights → Investigate → Live Metrics
   
   - **Performance**: Request/response analysis
     - Path: Application Insights → Investigate → Performance
   
   - **Failures**: Exception and error tracking
     - Path: Application Insights → Investigate → Failures
   
   - **Custom Workbook**: Pre-configured distributed tracing view
     - Path: Application Insights → Monitoring → Workbooks → Custom Workbook

### Via Azure CLI

```bash
# Query recent requests
az monitor app-insights query \
  --app appi-monitoring-lab-01 \
  --resource-group rg-monitoring-lab-canadacentral \
  --analytics-query "requests | top 10 by timestamp desc"

# Query exceptions
az monitor app-insights query \
  --app appi-monitoring-lab-01 \
  --resource-group rg-monitoring-lab-canadacentral \
  --analytics-query "exceptions | summarize count() by problemId | order by count_ desc"

# Query custom events
az monitor app-insights query \
  --app appi-monitoring-lab-01 \
  --resource-group rg-monitoring-lab-canadacentral \
  --analytics-query "customEvents | where name == 'FileProcessed' | project timestamp, name, customDimensions"
```

### Application Insights Connection String

Retrieve for local testing:

```bash
az monitor app-insights component show \
  --app appi-monitoring-lab-01 \
  --resource-group rg-monitoring-lab-canadacentral \
  --query connectionString -o tsv
```

Set as environment variable in your local Java app:

```bash
export APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=...;IngestionEndpoint=https://canadacentral-1.in.applicationinsights.azure.com/"
```

## Accessing Private Services

### PostgreSQL

**Via VPN**:
```bash
psql "host=psql-monitoring-lab-01.postgres.database.azure.com port=5432 dbname=labdb user=labadmin sslmode=require"
```

**Connection String** (stored in Key Vault):
```bash
az keyvault secret show \
  --vault-name kv-monitoring-lab-01 \
  --name postgresql-connection-string \
  --query value -o tsv
```

### Redis Cache

**Via VPN** (using redis-cli):
```bash
redis-cli -h redis-monitoring-lab-01.redis.cache.windows.net -p 6380 -a <access-key> --tls
```

**Access Key** (from Key Vault):
```bash
az keyvault secret show \
  --vault-name kv-monitoring-lab-01 \
  --name redis-access-key \
  --query value -o tsv
```

### Container Apps Ingress

Container Apps are configured with **internal-only** ingress. Access via:

1. **VPN Connection** + direct HTTPS:
   ```bash
   # Frontend
   curl https://frontend-ca.internal.<env-id>.canadacentral.azurecontainerapps.io
   
   # API
   curl https://api-ca.internal.<env-id>.canadacentral.azurecontainerapps.io/api/health
   ```

2. **Azure Portal** → Container Apps → Console (browser-based terminal)

3. **Azure CLI**:
   ```bash
   az containerapp show \
     --name frontend-ca \
     --resource-group rg-monitoring-lab-canadacentral \
     --query properties.configuration.ingress.fqdn -o tsv
   ```

## Troubleshooting

### VPN Connection Issues

**Problem**: Cannot connect to VPN

**Solutions**:
- Verify Azure AD credentials are valid
- Check firewall rules allow UDP 443, 1194-1197
- Re-download VPN configuration (may have expired)
- Restart Azure VPN Client

**Problem**: Connected to VPN but cannot reach private resources

**Solutions**:
- Verify DNS resolution: `nslookup psql-monitoring-lab-01.postgres.database.azure.com`
- Check routing table: `route print` (Windows) or `netstat -rn` (Linux/macOS)
- Ensure VPN client address is in 10.0.2.0/23 range: `ipconfig` / `ifconfig`

### Bastion Connection Issues

**Problem**: Cannot connect via Bastion

**Solutions**:
- Verify Bastion is deployed and running (check Azure Portal)
- Ensure target resource is in a VNet connected to the Virtual WAN hub
- Check NSG rules allow inbound traffic from Bastion subnet
- Clear browser cache and retry

### Application Insights - No Data

**Problem**: Application Insights shows no telemetry

**Solutions**:
- Verify Container Apps are running: `az containerapp list --resource-group rg-monitoring-lab-canadacentral`
- Check Application Insights connection string is set in Container Apps environment variables
- Review Container App logs: `az containerapp logs show --name frontend-ca --resource-group rg-monitoring-lab-canadacentral`
- Ensure adaptive sampling isn't filtering all data (check sampling settings)
- Wait 2-5 minutes for telemetry ingestion lag

**Problem**: Incomplete distributed tracing

**Solutions**:
- Verify all apps have same Application Insights instrumentation key
- Check correlation headers are propagated (`Request-Id`, `traceparent`)
- Review Application Insights agent logs in container startup logs

### Private Endpoint DNS Resolution

**Problem**: Cannot resolve private endpoint FQDNs

**Solutions**:
- Verify Private DNS Zones are created and linked to VNets
- Check A records exist in Private DNS Zones: `az network private-dns record-set a list --zone-name privatelink.postgres.database.azure.com --resource-group rg-monitoring-lab-canadacentral`
- Flush DNS cache:
  - Windows: `ipconfig /flushdns`
  - macOS: `sudo dscacheutil -flushcache`
  - Linux: `sudo systemd-resolve --flush-caches`

### Container Apps Not Starting

**Problem**: Container Apps stuck in "Provisioning" state

**Solutions**:
- Check Container App logs for image pull errors
- Verify ACR private endpoint DNS resolution
- Ensure managed identity has `AcrPull` role on ACR
- Check subnet delegation for `Microsoft.App/environments`
- Review Container App Environment health: `az containerapp env show --name cae-monitoring-lab-01 --resource-group rg-monitoring-lab-canadacentral`

## Additional Resources

- [Azure VPN Client Documentation](https://docs.microsoft.com/azure/vpn-gateway/openvpn-azure-ad-client)
- [Azure Bastion Documentation](https://docs.microsoft.com/azure/bastion/)
- [Application Insights Documentation](https://docs.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Container Apps Documentation](https://docs.microsoft.com/azure/container-apps/)

## Getting Help

For issues specific to this lab:
1. Check deployment logs: `./scripts/deploy.sh` output
2. Review Azure Activity Log in Portal
3. Open GitHub issue with detailed error messages
