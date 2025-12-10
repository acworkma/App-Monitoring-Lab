## Plan
We need to build out a repo that builds an lab enviroment for several Azure services, with Azure Monitoring and App Insight with the end goal of being able to demo App Insight 

## Spec
1. The first lab should deploy the necessary Azure resources 
    - Resource Group
    - VNets
    - App Container Service
    - Firewall 
    - PostgreSql Server
    - Redis cache
    - Datalake 
    - Key vault
    - Event Grid
    - Service bus
    - Azure Monitor
    - App Insight
    - Azure Container Registry

    the deployment should look similar to this mermaid diagram
    ```mermaid
flowchart TD
    subgraph Azure
        VNET1["data-vnet-01 (10.3.0.0/16)"]
        VNET2["ops-vnet-01"]
        SNET1["postgres-snet-01 (10.3.1.0/24)
Delegated to PostgreSQL Flexible Servers"]
        SNET2["aca-snet-01 (10.5.0.0/23)"]
        HUB["hub-vwanhub-01"]
        P2S["hub-p2sgw-01 (P2S VPN)
10.0.2.0/23"]
        FW["hub-hubfw-01 (Firewall)"]
        PE1["pe-snet-01 (10.3.0.0/24) Private Endpoints"]
        PE2["pe-ops-snet-01 (10.5.2.0/24) Private Endpoints"]
    end

    subgraph ContainerApps
        CAE["cae-01 (Container App Environment)"]
        Redis["redis-01 (Azure Cache for Redis)"]
        KeyVault["kv-01 (Key Vault)"]
        ServiceBus["sbus-01 (Service Bus)"]
        PG["psql-01 (PG Flexible Server)"]
    end

    subgraph Storage
        ADL["dlstore01 (Data Lake Storage)"]
        ADLPE["dlstore-pe 10.3.0.7"]
    end

    Laptop[(Laptop Admin)]
    Bastion[(Bastion Host)]
    WebIngress["Web (HTTPS 443)
10.5.1.156"]

    Laptop -->|Browser/Venn| Bastion
    Bastion --> CAE
    CAE --> Redis
    CAE --> KeyVault
    CAE --> ServiceBus
    CAE --> PG

    ADL --> ServiceBus
    ADLPE --> ServiceBus

    WebIngress --> CAE
    FW --> CAE
    FW --> Redis
    FW --> PG

    EventGrid["Event Grid System Topics"] --> ServiceBus

```
follow best practices from Azure MCP and Azure Verified Modules https://github.com/Azure/Azure-Verified-Modules

2. the second lab should should deploy a sample application that exercises the underlying componets so traffic will be generated to display in App Monitor 


