# Architecture Documentation

Detailed architecture documentation for the Azure Application Insights Monitoring Lab.

## Table of Contents

- [Overview](#overview)
- [Network Architecture](#network-architecture)
- [Compute Architecture](#compute-architecture)
- [Data Architecture](#data-architecture)
- [Security Architecture](#security-architecture)
- [Monitoring Architecture](#monitoring-architecture)
- [Application Architecture](#application-architecture)
- [Design Decisions](#design-decisions)

## Overview

This lab implements a production-ready Azure architecture demonstrating Application Insights monitoring capabilities with a 3-tier Java Spring Boot application.

### Key Design Principles

1. **Security First**: All services accessed via private endpoints, no public exposure
2. **Observability**: Comprehensive telemetry with Application Insights and Log Analytics
3. **Scalability**: Container Apps with auto-scaling based on HTTP and queue metrics
4. **Resiliency**: Zone redundancy for critical services, health probes, retry policies
5. **Infrastructure as Code**: 100% Bicep with Azure Verified Modules

## Network Architecture

### Virtual WAN Hub-Spoke Topology

```
                    ┌─────────────────────────┐
                    │   Virtual WAN Hub       │
                    │   (Canada Central)      │
                    │                         │
                    │  ┌──────────────────┐  │
                    │  │  Azure Firewall  │  │
                    │  │   (Standard)     │  │
                    │  │  Allow-All Policy│  │
                    │  └────────┬─────────┘  │
                    │           │             │
                    │  ┌────────┴─────────┐  │
                    │  │  P2S VPN Gateway │  │
                    │  │  (Azure AD Auth) │  │
                    │  │   10.0.2.0/23    │  │
                    │  └──────────────────┘  │
                    └───┬─────────────────┬──┘
                        │                 │
        ┌───────────────┴──┐         ┌───┴────────────────┐
        │  data-vnet-01    │         │  ops-vnet-01       │
        │  10.3.0.0/16     │         │  10.5.0.0/16       │
        └──────────────────┘         └────────────────────┘
```

### Subnet Allocation

#### data-vnet-01 (10.3.0.0/16)

| Subnet | CIDR | Size | Purpose | Delegation |
|--------|------|------|---------|------------|
| pe-snet-01 | 10.3.0.0/24 | 256 | Private endpoints (Storage, Redis, Service Bus) | None |
| postgres-snet-01 | 10.3.1.0/24 | 256 | PostgreSQL Flexible Server | `Microsoft.DBforPostgreSQL/flexibleServers` |

#### ops-vnet-01 (10.5.0.0/16)

| Subnet | CIDR | Size | Purpose | Delegation |
|--------|------|------|---------|------------|
| aca-snet-01 | 10.5.0.0/23 | 512 | Container App Environment | `Microsoft.App/environments` |
| pe-ops-snet-01 | 10.5.2.0/24 | 256 | Private endpoints (ACR, Key Vault) | None |
| AzureBastionSubnet | 10.5.3.0/26 | 64 | Azure Bastion | None (Reserved) |

### Private DNS Zones

All services use private endpoints with Private DNS Zone integration:

| Service | Private DNS Zone | A Record Example |
|---------|------------------|------------------|
| PostgreSQL | `privatelink.postgres.database.azure.com` | `psql-monitoring-lab-01.postgres.database.azure.com` → 10.3.1.4 |
| Redis | `privatelink.redis.cache.windows.net` | `redis-monitoring-lab-01.redis.cache.windows.net` → 10.3.0.5 |
| Key Vault | `privatelink.vaultcore.azure.net` | `kv-monitoring-lab-01.vault.azure.net` → 10.5.2.4 |
| Service Bus | `privatelink.servicebus.windows.net` | `sbus-monitoring-lab-01.servicebus.windows.net` → 10.3.0.6 |
| Storage (Data Lake) | `privatelink.dfs.core.windows.net` | `dlstore01.dfs.core.windows.net` → 10.3.0.7 |
| Container Registry | `privatelink.azurecr.io` | `acrmonitoringlab01.azurecr.io` → 10.5.2.5 |

**DNS Resolution Flow**:
1. Container App queries `psql-monitoring-lab-01.postgres.database.azure.com`
2. Azure DNS resolves via linked Private DNS Zone
3. Returns private IP (10.3.1.4) instead of public IP
4. Traffic stays within Azure backbone, never traverses internet

### Routing and Firewall

- **Default Route**: All spoke-to-spoke traffic routes through Virtual WAN hub
- **Firewall Policy**: Allow-all for lab simplicity (can be restricted for production)
- **Forced Tunneling**: VPN client traffic also routes through firewall
- **Spoke Isolation**: Spokes cannot communicate directly, must traverse hub

## Compute Architecture

### Container App Environment

**SKU**: Workload Profiles (Dedicated-D4)
- 4 vCPUs, 16 GB memory per profile
- Zone redundancy enabled
- Internal-only ingress (private FQDN)

### Container Apps

#### Frontend Application (`frontend-ca`)

```yaml
Image: acrmonitoringlab01.azurecr.io/frontend:latest
Replicas: 1-10 (auto-scale on HTTP requests)
Resources:
  CPU: 1.0 cores
  Memory: 2.0 Gi
Ingress:
  External: false (internal only)
  Target Port: 8080
  Transport: HTTP/2
Environment Variables:
  - API_BASE_URL: https://api-ca.internal.<env-id>.canadacentral.azurecontainerapps.io
  - APPLICATIONINSIGHTS_CONNECTION_STRING: @Microsoft.KeyVault(SecretUri=...)
Health Probes:
  Liveness: /actuator/health/liveness
  Readiness: /actuator/health/readiness
```

#### API Application (`api-ca`)

```yaml
Image: acrmonitoringlab01.azurecr.io/api:latest
Replicas: 2-10 (auto-scale on HTTP + CPU >70%)
Resources:
  CPU: 1.5 cores
  Memory: 3.0 Gi
Ingress:
  External: false
  Target Port: 8080
Environment Variables:
  - SPRING_DATASOURCE_URL: @Microsoft.KeyVault(SecretUri=...)
  - SPRING_REDIS_HOST: redis-monitoring-lab-01.redis.cache.windows.net
  - SPRING_REDIS_PASSWORD: @Microsoft.KeyVault(SecretUri=...)
  - AZURE_SERVICEBUS_CONNECTION_STRING: @Microsoft.KeyVault(SecretUri=...)
  - APPLICATIONINSIGHTS_CONNECTION_STRING: @Microsoft.KeyVault(SecretUri=...)
```

#### Worker Application (`worker-ca`)

```yaml
Image: acrmonitoringlab01.azurecr.io/worker:latest
Replicas: 1-5 (auto-scale on Service Bus queue length >10 messages)
Resources:
  CPU: 1.0 cores
  Memory: 2.0 Gi
Ingress: None (background worker)
Environment Variables:
  - AZURE_SERVICEBUS_CONNECTION_STRING: @Microsoft.KeyVault(SecretUri=...)
  - AZURE_STORAGE_CONNECTION_STRING: @Microsoft.KeyVault(SecretUri=...)
  - SPRING_DATASOURCE_URL: @Microsoft.KeyVault(SecretUri=...)
  - APPLICATIONINSIGHTS_CONNECTION_STRING: @Microsoft.KeyVault(SecretUri=...)
```

### Scaling Rules

- **Frontend**: HTTP concurrency >100 requests → scale out
- **API**: HTTP concurrency >100 + CPU >70% → scale out
- **Worker**: Service Bus queue depth >10 messages → scale out
- **Cool-down**: 5 minutes before scaling in
- **Max Replicas**: 10 (adjustable based on testing)

## Data Architecture

### PostgreSQL Flexible Server

**Configuration**:
- SKU: General Purpose, D4ds_v4 (4 vCPU, 16 GB RAM)
- Storage: 128 GB, auto-grow enabled
- Version: PostgreSQL 15
- High Availability: Zone-redundant standby
- Backup: 7-day retention, geo-redundant
- Extensions: `pgaudit`, `pg_stat_statements`

**Database Schema**:
```sql
-- Created via Flyway migrations
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    quantity INTEGER,
    status VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE file_processing_logs (
    id SERIAL PRIMARY KEY,
    file_name VARCHAR(255),
    file_size BIGINT,
    status VARCHAR(50),
    processed_at TIMESTAMP,
    error_message TEXT
);
```

### Azure Cache for Redis

**Configuration**:
- SKU: Premium P1 (6 GB)
- Clustering: Disabled (sufficient for lab)
- Persistence: RDB backup enabled (12 hours)
- TLS: Required (minimum version 1.2)
- Access: Private endpoint only

**Caching Strategy**:
- Product catalog cached for 5 minutes
- Order status cached for 1 minute
- Cache-aside pattern with Spring Cache abstraction
- Redis key pattern: `{service}:{entity}:{id}` (e.g., `api:product:123`)

### Data Lake Storage Gen2

**Configuration**:
- Performance: Standard (hot tier)
- Replication: LRS (locally-redundant storage)
- Hierarchical Namespace: Enabled
- Public Access: Disabled
- Container: `uploads` (for file ingestion)

**Event Grid Integration**:
```
Blob Created → Event Grid System Topic → Service Bus Queue → Worker App
```

## Security Architecture

### Identity and Access Management

**Managed Identities**:
- User-assigned managed identity: `mi-monitoring-lab-01`
- Assigned to all Container Apps
- Role assignments:
  - `Key Vault Secrets User` on Key Vault
  - `AcrPull` on Container Registry
  - `Storage Blob Data Contributor` on Storage Account
  - `Azure Service Bus Data Receiver` on Service Bus

**Key Vault Secrets**:
- `postgresql-connection-string`
- `redis-access-key`
- `servicebus-connection-string`
- `storage-connection-string`
- `applicationinsights-connection-string`

**Secret Rotation**: Manual for lab, recommend Azure Key Vault secret rotation policies for production

### Network Security

**Private Endpoints**: All data plane traffic stays within Azure backbone
**NSG Rules**: Minimal (delegated subnets managed by Azure)
**Firewall**: Allow-all for lab, recommend explicit allow-lists for production
**TLS**: Required for all service-to-service communication

### Authentication

- **VPN**: Azure AD authentication (no certificates to manage)
- **Bastion**: Azure AD or SSH keys
- **Service-to-Service**: Managed identity where possible, connection strings in Key Vault

## Monitoring Architecture

### Application Insights Configuration

**Instrumentation**:
- **Automatic**: `applicationinsights-agent-3.5.x.jar` attached to JVM
- **Custom**: Spring Boot SDK for business events

**Sampling Strategy**:
- **Mode**: Adaptive (adjusts rate based on traffic)
- **Max Telemetry Rate**: 5 items/second per server instance
- **Fixed Rate Fallback**: 50% if adaptive fails

**Telemetry Types Collected**:
1. **Requests**: HTTP requests to frontend/API with duration, response code
2. **Dependencies**: Calls to Redis, PostgreSQL, Service Bus, Storage
3. **Exceptions**: Unhandled exceptions with stack traces
4. **Custom Events**: Business events (e.g., `FileUploaded`, `OrderCreated`)
5. **Metrics**: JVM metrics, custom business metrics
6. **Traces**: Log statements (INFO and above)

### Log Analytics Workspace

**Configuration**:
- Pricing Tier: PerGB2018 (pay-as-you-go)
- Data Retention: 90 days
- Daily Cap: 10 GB (alert configured)

**Data Sources**:
- Application Insights telemetry
- Container App logs (stdout/stderr)
- Azure resource diagnostic logs (PostgreSQL, Redis, Service Bus, etc.)
- Azure Activity Log

### Distributed Tracing

**Correlation**:
- W3C Trace Context standard (`traceparent` header)
- Automatic correlation across all services
- Operation ID propagated through: Frontend → API → Redis/PostgreSQL/Service Bus → Worker → Data Lake

**Tracing Example**:
```
User Request (operation_Id: abc123)
├─ Frontend: GET /upload (duration: 45ms)
│  └─ Dependency: API POST /api/files (duration: 30ms)
│     ├─ Dependency: Redis GET product:123 (duration: 2ms)
│     ├─ Dependency: PostgreSQL INSERT (duration: 8ms)
│     └─ Dependency: Service Bus SEND (duration: 5ms)
│
└─ Worker: Process Message (duration: 120ms)
   ├─ Dependency: Storage GET blob (duration: 50ms)
   ├─ Dependency: PostgreSQL UPDATE (duration: 10ms)
   └─ Custom Event: FileProcessed
```

### Alert Rules

Configured alerts:
1. **Availability < 95%** (5-minute window)
2. **Response Time p95 > 3 seconds** (10-minute window)
3. **Exception Rate > 10 per 5 minutes**
4. **Dependency Failure Rate > 5%** (5-minute window)
5. **Log Analytics Daily Cap Reached**

## Application Architecture

### Frontend (Spring Boot + Thymeleaf)

**Responsibilities**:
- Serve HTML pages with file upload form
- Proxy API calls
- Display product catalog and order status

**Dependencies**:
- Spring Boot Web
- Thymeleaf template engine
- Application Insights Spring Boot Starter

### API (Spring Boot REST)

**Responsibilities**:
- REST endpoints for products, orders, file uploads
- Redis caching layer
- PostgreSQL persistence
- Publish messages to Service Bus

**Endpoints**:
- `GET /api/products` - List products (cached)
- `GET /api/products/{id}` - Get product (cached)
- `POST /api/orders` - Create order
- `GET /api/orders/{id}` - Get order status (cached)
- `POST /api/files` - Upload file to Data Lake
- `GET /actuator/health` - Health check

**Dependencies**:
- Spring Boot Web
- Spring Data JPA
- Spring Data Redis
- Spring JMS (Service Bus)
- Flyway (database migrations)
- Application Insights

### Worker (Spring Boot Background Service)

**Responsibilities**:
- Consume messages from Service Bus queue
- Download files from Data Lake Storage
- Process files (parse, validate, transform)
- Update PostgreSQL with processing results

**Message Processing**:
1. Receive message from Service Bus
2. Extract blob URL from message
3. Download blob from Data Lake
4. Process file content
5. Update `file_processing_logs` table
6. Complete message (remove from queue)
7. Emit `FileProcessed` custom event

**Dependencies**:
- Spring Boot
- Spring JMS (Service Bus)
- Azure Storage Blob SDK
- Application Insights

### Data Flow

```
┌──────────┐
│  User    │
└────┬─────┘
     │ 1. Upload file via UI
     ▼
┌──────────┐
│ Frontend │
└────┬─────┘
     │ 2. POST /api/files
     ▼
┌──────────┐      3. Store file        ┌───────────┐
│   API    │─────────────────────────>│ Data Lake │
└────┬─────┘                           └─────┬─────┘
     │                                        │
     │ 4. Publish message                    │ 5. Blob Created Event
     ▼                                        ▼
┌──────────────┐                        ┌────────────┐
│ Service Bus  │<───────────────────────│ Event Grid │
└────┬─────────┘                        └────────────┘
     │
     │ 6. Poll messages
     ▼
┌──────────┐      7. Download file      ┌───────────┐
│  Worker  │─────────────────────────>│ Data Lake │
└────┬─────┘                           └───────────┘
     │
     │ 8. Update processing log
     ▼
┌──────────┐
│PostgreSQL│
└──────────┘
```

## Design Decisions

### Why Virtual WAN?

- **Centralized Management**: Single hub for multiple spokes (scalable for adding more VNets)
- **Integrated Firewall**: Managed Azure Firewall with automatic routing
- **Global Reach**: Easy to extend to multi-region in future
- **P2S VPN**: Built-in VPN gateway with Azure AD auth

**Trade-off**: Higher cost and complexity vs traditional hub-spoke with VNet peering. Justified for enterprise-grade lab demonstrating production patterns.

### Why Container Apps?

- **Simplified Management**: No Kubernetes cluster management
- **Auto-scaling**: Built-in HTTP and queue-based scaling
- **Dapr Integration**: Optional for future microservices patterns
- **Cost-Effective**: Consumption-based pricing with scale-to-zero (disabled for lab)

**Alternative Considered**: AKS (Azure Kubernetes Service) - more control but higher operational overhead.

### Why PostgreSQL Flexible Server?

- **VNet Integration**: Native private networking without private endpoints
- **Zone Redundancy**: High availability with automatic failover
- **Performance**: Better performance vs Single Server (deprecated)
- **Features**: Support for extensions like pgAudit

### Why Premium Redis?

- **Private Endpoints**: Required for VNet integration
- **Persistence**: RDB backups for data durability
- **SLA**: 99.95% uptime guarantee

**Trade-off**: Higher cost vs Standard/Basic. Justified for production-like lab with private networking.

### Why Java Spring Boot?

- **Enterprise Standard**: Widely used in enterprise applications
- **Application Insights Support**: Excellent Java agent with auto-instrumentation
- **Spring Ecosystem**: Comprehensive libraries for data access, caching, messaging
- **Ease of Use**: Spring Boot simplifies configuration and deployment

### Why Adaptive Sampling?

- **Cost Optimization**: Reduces telemetry volume without losing insights
- **Intelligent**: Preserves rare events (exceptions) and diverse request types
- **Dynamic**: Adjusts to traffic patterns automatically

**Trade-off**: May miss some data points. For lab demos, 100% sampling could be enabled by setting fixed rate to 100.

### Why Bicep (not Terraform)?

- **Azure-Native**: First-class support from Microsoft
- **Azure Verified Modules**: Pre-built, tested modules following best practices
- **Type Safety**: Strong typing with intellisense
- **Simpler Syntax**: More concise than ARM templates

## Future Enhancements

1. **Multi-Region**: Extend to secondary region with Traffic Manager
2. **CI/CD**: Azure DevOps pipelines in addition to GitHub Actions
3. **Chaos Engineering**: Introduce failures with Azure Chaos Studio
4. **Advanced Monitoring**: Prometheus/Grafana integration
5. **Security**: Defender for Cloud, Azure Policy enforcement
6. **Cost Optimization**: Reserved instances, spot instances for non-critical workloads
