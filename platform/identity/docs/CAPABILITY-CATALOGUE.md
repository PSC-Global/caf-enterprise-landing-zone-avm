# Capability Catalogue Reference

This document provides a comprehensive reference for all capabilities defined in the Identity & Access Baseline system. Each capability represents a functional responsibility boundary with standardized access levels.

---

## Capability Overview

| # | Capability | Purpose | Access Levels |
|---|-----------|---------|--------------|
| 1 | **Identity** | Manage Entra ID–related Azure resources | Viewer, Operator, Contributor, Admin |
| 2 | **Governance** | Policies, tagging, compliance, cost governance | Viewer, Contributor, Admin |
| 3 | **Network** | VNETs, private endpoints, routing, DNS, load balancers, firewalls | Viewer, Contributor, Admin |
| 4 | **Compute** | VMs, App Services, AKS, disk management | Viewer, Operator, Contributor, Admin |
| 5 | **Storage** | Storage accounts, blob, queue, file shares | Viewer, Contributor, Admin |
| 6 | **Data & Analytics** | SQL, Cosmos DB, Data Factory, Synapse | Viewer, Contributor, Admin |
| 7 | **AI & Machine Learning** | Cognitive Services, Azure ML | Viewer, Operator, Contributor, Admin |
| 8 | **Security** | Security posture, Defender, Sentinel | Viewer, Contributor, Admin |
| 9 | **Integration** | Logic Apps, API Management, Service Bus, Event Grid | Viewer, Operator, Contributor, Admin |
| 10 | **IoT** | IoT Hub, Device Provisioning, Digital Twins | Viewer, Contributor, Admin |
| 11 | **Monitoring & Operations** | Log Analytics, Application Insights, Automation | Viewer, Operator, Contributor, Admin |

---

## 1. Identity Capability

### Purpose

Manage Entra ID–related Azure resources (not tenant-level Entra). This capability covers managed identities, identity-related Azure resources, and access management scoped to resource groups or subscriptions.

### Configuration

```yaml
capability: identity

accessLevels:
  viewer:
    - Reader
  operator:
    - Managed Identity Operator
  contributor:
    - Managed Identity Contributor
  admin:
    - Contributor
    - User Access Administrator

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Reader | View identity resources for audit, troubleshooting, or compliance |
| **Operator** | Managed Identity Operator | Assign managed identities to resources (compute teams need this) |
| **Contributor** | Managed Identity Contributor | Create and manage system-assigned and user-assigned identities |
| **Admin** | Contributor, User Access Administrator | Full control over identity resources and role assignments (scoped to identity RGs) |

### Justification

- **Compute teams need MSI operators**: Application teams require Managed Identity Operator to assign managed identities to their compute resources (VMs, App Services, AKS) without needing full identity management rights.

- **Identity platform teams manage identities**: Central identity teams need Managed Identity Contributor to create and manage system-assigned and user-assigned identities across the platform.

- **No tenant-level Entra admin**: This capability is scoped to Azure resources only. Tenant-level Entra ID administration requires separate, highly restricted permissions outside this capability model.

- **User Access Administrator scoped**: Admin level includes User Access Administrator, but this is scoped only to identity resource groups, preventing broad access management across the entire subscription.

---

## 2. Governance Capability

### Purpose

Policies, tagging, compliance, blueprints, cost governance. This capability enables teams to manage Azure Policy, resource tagging, cost management, and compliance reporting.

### Configuration

```yaml
capability: governance

accessLevels:
  viewer:
    - Reader
  operator: []
  contributor:
    - Cost Management Contributor
    - Resource Policy Contributor
  admin:
    - Contributor
    - User Access Administrator

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Reader | View policies, compliance status, and cost reports |
| **Operator** | *(None)* | No operator level required for governance |
| **Contributor** | Cost Management Contributor, Resource Policy Contributor | Create/modify policies, manage cost budgets, assign policy definitions |
| **Admin** | Contributor, User Access Administrator | Full control over governance resources and policy assignments |

### Justification

- **Governance = backbone of compliance**: Policy management is critical for maintaining compliance standards across the organization. Teams need the ability to create, modify, and assign policies without requiring broader infrastructure access.

- **Admins need to modify/assign policies**: Governance teams require Resource Policy Contributor to create custom policy definitions and assign them to management groups or subscriptions.

- **Cost management is governance**: Cost Management Contributor allows teams to set budgets, create cost alerts, and manage cost allocation without needing subscription-level Contributor access.

- **No identity or compute control**: Governance teams can manage policies and costs but cannot modify identity resources or compute infrastructure directly.

---

## 3. Network Capability

### Purpose

Everything related to VNETs, private endpoints, routing, DNS, load balancers, firewalls. This capability covers all networking infrastructure and connectivity services in Azure.

### Configuration

```yaml
capability: network

accessLevels:
  viewer:
    - Reader
  operator: []
  contributor:
    - DNS Zone Contributor
    - Network Contributor
    - Private DNS Zone Contributor
    - Traffic Manager Contributor
  admin:
    - Contributor

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Reader | View network resources, routing tables, NSG rules for troubleshooting |
| **Operator** | *(None)* | No operator level required for network |
| **Contributor** | Network Contributor, DNS Zone Contributor, Private DNS Zone Contributor, Traffic Manager Contributor | Create/modify VNETs, subnets, NSGs, load balancers, DNS zones, private endpoints |
| **Admin** | Contributor | Full control over network resources (no User Access Administrator to prevent scope creep) |

### Justification

- **Network Contributor is the main workhorse**: This role provides comprehensive network management capabilities including VNETs, subnets, network security groups, load balancers, and application gateways.

- **DNS management is separate**: DNS Zone Contributor and Private DNS Zone Contributor are included separately to allow fine-grained control over DNS resources, which are often managed by different teams.

- **Traffic Manager for global routing**: Traffic Manager Contributor enables management of global traffic routing and failover scenarios.

- **Admins should NOT have control beyond network scopes**: Network admins get Contributor (full network control) but not User Access Administrator, preventing them from managing access to non-network resources.

---

## 4. Compute Capability

### Purpose

VMs, App Services, AKS, disk management. This capability covers all compute resources including virtual machines, container services, and serverless compute platforms.

### Configuration

```yaml
capability: compute

accessLevels:
  viewer:
    - Monitoring Reader
    - Reader
  operator:
    - Managed Identity Operator
    - Virtual Machine User Login
  contributor:
    - Azure Kubernetes Service Contributor
    - Disk Snapshot Contributor
    - Virtual Machine Contributor
    - Web Plan Contributor
    - Website Contributor
  admin:
    - Contributor
    - User Access Administrator
    - Virtual Machine Administrator Login

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Reader, Monitoring Reader | View compute resources and their monitoring data |
| **Operator** | Managed Identity Operator, Virtual Machine User Login | Login to VMs, assign managed identities to compute resources |
| **Contributor** | Virtual Machine Contributor, Azure Kubernetes Service Contributor, Website Contributor, Web Plan Contributor, Disk Snapshot Contributor | Deploy and manage VMs, AKS clusters, App Services, create disk snapshots |
| **Admin** | Contributor, User Access Administrator, Virtual Machine Administrator Login | Full control including admin login to VMs and role assignment management |

### Justification

- **Perfect balance of VM + AppService + AKS operations**: The contributor level includes roles for all major compute platforms, allowing teams to deploy and manage diverse workloads without needing broader Contributor access.

- **Managed Identity Operator for compute**: Compute teams need to assign managed identities to their VMs, App Services, and AKS clusters, which requires Managed Identity Operator (from Identity capability) but is included here for operational convenience.

- **Virtual Machine User Login for day-to-day ops**: Operators can login to VMs for troubleshooting and maintenance without needing full Contributor access.

- **Disk Snapshot Contributor for backup/DR**: Teams can create disk snapshots for backup and disaster recovery scenarios.

- **Virtual Machine Administrator Login for admin tasks**: Admin level includes the ability to login as administrator to VMs for advanced troubleshooting and configuration.

- **No networking or storage control**: Compute teams can manage compute resources but cannot modify network infrastructure or storage accounts directly.

---

## 5. Storage Capability

### Purpose

Storage accounts, blob, queue, file shares. This capability covers all Azure Storage services including blob, file, queue, and table storage.

### Configuration

```yaml
capability: storage

accessLevels:
  viewer:
    - Reader
    - Storage Blob Data Reader
  operator: []
  contributor:
    - Storage Account Contributor
    - Storage Blob Data Contributor
    - Storage Queue Data Contributor
    - Storage File Data SMB Share Contributor
  admin:
    - Contributor

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Reader, Storage Blob Data Reader | View storage accounts and read blob data |
| **Operator** | *(None)* | No operator level required for storage |
| **Contributor** | Storage Account Contributor, Storage Blob Data Contributor, Storage Queue Data Contributor, Storage File Data SMB Share Contributor | Create/modify storage accounts, read/write blob/queue/file data |
| **Admin** | Contributor | Full control over storage resources (scoped to resource groups) |

### Justification

- **Split control-plane vs data-plane roles**: Storage Account Contributor manages the storage account itself (control plane), while data contributor roles (Storage Blob Data Contributor, etc.) manage the actual data (data plane). This separation allows fine-grained access control.

- **Storage Blob Data Reader for read-only access**: Viewers can read blob data without needing full storage account access, useful for data analysts and reporting teams.

- **Multiple data contributor roles**: Separate roles for blob, queue, and file storage allow teams to grant access only to the storage types they need.

- **Admin limited to RG scope**: Storage admins get Contributor but this is typically scoped to resource groups, preventing broad storage access across subscriptions.

---

## 6. Data & Analytics Capability

### Purpose

SQL, Cosmos DB, Data Factory, Synapse. This capability covers all database and analytics services in Azure.

### Configuration

```yaml
capability: data

accessLevels:
  viewer:
    - Reader
    - Storage Blob Data Reader
  operator: []
  contributor:
    - Cosmos DB Account Contributor
    - Data Factory Contributor
    - SQL DB Contributor
    - SQL Server Contributor
    - Synapse Contributor
  admin:
    - Contributor

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Reader, Storage Blob Data Reader | View databases, read data from storage (for analytics), view data factory pipelines |
| **Operator** | *(None)* | No operator level required for data |
| **Contributor** | SQL DB Contributor, SQL Server Contributor, Cosmos DB Account Contributor, Data Factory Contributor, Synapse Contributor | Create/modify databases, manage data pipelines, configure analytics workspaces |
| **Admin** | Contributor | Full control over data resources (DBA-level access without data reading permissions) |

### Justification

- **DBA-level control without reading data**: SQL DB Contributor and SQL Server Contributor allow database administrators to manage database infrastructure, schemas, and configurations without automatically granting data reading permissions (which require separate data reader roles).

- **Cosmos DB for NoSQL workloads**: Cosmos DB Account Contributor enables management of globally distributed NoSQL databases.

- **Data Factory for ETL pipelines**: Data Factory Contributor allows teams to create and manage data integration pipelines for ETL operations.

- **Synapse for analytics**: Synapse Contributor enables management of Azure Synapse Analytics workspaces for big data analytics.

- **Storage Blob Data Reader for data access**: Viewers can read data from storage accounts, which is often needed for analytics and reporting scenarios.

- **Contributor reserved for special operations**: Admin level provides full Contributor access for advanced database management tasks, but this is typically scoped to resource groups.

---

## 7. AI & Machine Learning Capability

### Purpose

Cognitive Services, Azure ML. This capability covers all AI and machine learning services including Azure Machine Learning, Cognitive Services, and related ML infrastructure.

### Configuration

```yaml
capability: ai

accessLevels:
  viewer:
    - Reader
  operator:
    - AzureML Compute Operator
    - Cognitive Services User
  contributor:
    - AzureML Data Scientist
    - AzureML Registry User
    - Cognitive Services Contributor
  admin:
    - Contributor

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Reader | View ML workspaces, models, and cognitive services |
| **Operator** | AzureML Compute Operator, Cognitive Services User | Run ML training jobs, use cognitive services APIs for inference |
| **Contributor** | AzureML Data Scientist, AzureML Registry User, Cognitive Services Contributor | Create/modify ML models, manage ML registries, configure cognitive services |
| **Admin** | Contributor | Full control over AI/ML resources |

### Justification

- **Cognitive + ML roles needed for model training and operational inference**: AzureML Data Scientist allows data scientists to train, deploy, and manage ML models. Cognitive Services Contributor enables configuration of cognitive service endpoints.

- **AzureML Compute Operator for job execution**: Operators can submit and manage ML training jobs without needing full workspace contributor access.

- **AzureML Registry User for model sharing**: Teams can publish and consume models from the ML registry, enabling model sharing across projects.

- **Cognitive Services User for API access**: Operators can use cognitive services APIs (vision, language, speech) for inference without managing the services themselves.

- **Separation of training vs operations**: The operator level allows running ML workloads, while contributor level enables model development and deployment.

---

## 8. Security Capability

### Purpose

Security posture, Defender, Sentinel. This capability covers security operations, threat detection, and security compliance management.

### Configuration

```yaml
capability: security

accessLevels:
  viewer:
    - Security Reader
  operator: []
  contributor:
    - Defender for Cloud Contributor
    - Microsoft Sentinel Contributor
  admin:
    - Contributor
    - Security Admin

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Security Reader | View security recommendations, alerts, compliance status |
| **Operator** | *(None)* | No operator level required for security |
| **Contributor** | Defender for Cloud Contributor, Microsoft Sentinel Contributor | Configure security policies, manage Sentinel workspaces, set up threat detection rules |
| **Admin** | Contributor, Security Admin | Full control over security resources and security policy management |

### Justification

- **Centralized SecOps needs visibility**: Security Reader provides comprehensive visibility into security posture, recommendations, and compliance status across all resources.

- **Defender policy updates**: Defender for Cloud Contributor allows security teams to configure security policies, enable/disable security features, and manage security recommendations.

- **Sentinel for SIEM operations**: Microsoft Sentinel Contributor enables security teams to create and manage Sentinel workspaces, configure data connectors, and create detection rules.

- **Security Admin for policy management**: Admin level includes Security Admin role, which allows management of security policies and security center settings at subscription or management group scope.

- **Admin gives ability to modify only within selected scopes**: Security admins can manage security resources but this is typically scoped to specific subscriptions or resource groups, preventing broad access management.

---

## 9. Integration Capability

### Purpose

Logic Apps, API Management, Service Bus, Event Grid. This capability covers all integration and messaging services that connect different systems and applications.

### Configuration

```yaml
capability: integration

accessLevels:
  viewer:
    - Reader
  operator:
    - Logic App Operator
  contributor:
    - API Management Service Contributor
    - EventGrid Contributor
    - Integration Service Environment Contributor
    - Logic App Contributor
    - Service Bus Data Owner
  admin:
    - Contributor

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Reader | View integration resources, API definitions, and messaging queues |
| **Operator** | Logic App Operator | Run and manage Logic App workflows, view execution history |
| **Contributor** | Logic App Contributor, API Management Service Contributor, Service Bus Data Owner, EventGrid Contributor, Integration Service Environment Contributor | Create/modify Logic Apps, manage APIs, configure messaging queues, set up event routing |
| **Admin** | Contributor | Full control over integration resources |

### Justification

- **Integration teams need glue-service control**: Integration teams manage the services that connect different systems (APIs, messaging, workflows) without needing access to compute or network infrastructure.

- **Logic App Operator for workflow execution**: Operators can run Logic App workflows and view execution history without needing to modify the workflow definitions.

- **API Management for API governance**: API Management Service Contributor enables teams to create, configure, and manage API gateways and API policies.

- **Service Bus Data Owner for messaging**: Teams can send/receive messages and manage queues/topics in Service Bus.

- **EventGrid for event-driven architecture**: EventGrid Contributor allows configuration of event subscriptions and routing for event-driven applications.

- **Integration Service Environment for ISE**: Integration Service Environment Contributor enables management of dedicated integration environments for Logic Apps and API Management.

- **Without touching compute or network**: Integration teams can manage integration services but cannot modify VMs, networking, or other infrastructure components.

---

## 10. IoT Capability

### Purpose

IoT Hub, Device Provisioning, Digital Twins. This capability covers all Internet of Things services including device management, telemetry, and digital twin services.

### Configuration

```yaml
capability: iot

accessLevels:
  viewer:
    - IoT Hub Reader
    - Reader
  operator: []
  contributor:
    - Device Provisioning Service Contributor
    - Digital Twins Contributor
    - IoT Hub Contributor
    - IoT Hub Data Contributor
  admin:
    - Contributor

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Reader, IoT Hub Reader | View IoT hubs, device registrations, and telemetry metadata |
| **Operator** | *(None)* | No operator level required for IoT |
| **Contributor** | IoT Hub Contributor, IoT Hub Data Contributor, Device Provisioning Service Contributor, Digital Twins Contributor | Create/modify IoT hubs, send/receive device telemetry, manage device provisioning, configure digital twins |
| **Admin** | Contributor | Full control over IoT resources |

### Justification

- **IoT data-plane separation**: IoT Hub Contributor manages the IoT hub infrastructure (control plane), while IoT Hub Data Contributor manages device telemetry and messaging (data plane). This separation allows fine-grained access control.

- **Device Provisioning for automated onboarding**: Device Provisioning Service Contributor enables management of device enrollment and automated provisioning workflows.

- **Digital Twins for spatial intelligence**: Digital Twins Contributor allows configuration of Azure Digital Twins for modeling physical environments and IoT device relationships.

- **Telemetry ops vs infra ops**: IoT Hub Data Contributor allows teams to send and receive device telemetry without needing full IoT Hub Contributor access, enabling separation between device operations and infrastructure management.

- **IoT Hub Reader for monitoring**: Viewers can monitor IoT hub status and device registrations without accessing telemetry data.

---

## 11. Monitoring & Operations Capability

### Purpose

Log Analytics, Application Insights, Automation. This capability covers all observability, logging, and operational automation services.

### Configuration

```yaml
capability: monitoring

accessLevels:
  viewer:
    - Log Analytics Reader
    - Monitoring Reader
  operator:
    - Log Analytics Contributor
  contributor:
    - Application Insights Component Contributor
    - Automation Contributor
    - Monitoring Contributor
  admin:
    - Contributor

assignments: []
```

### Access Levels & Roles

| Access Level | Azure RBAC Roles | Use Case |
|-------------|------------------|----------|
| **Viewer** | Log Analytics Reader, Monitoring Reader | View logs, metrics, and monitoring data for troubleshooting and compliance |
| **Operator** | Log Analytics Contributor | Write logs, create custom log queries, manage log data ingestion |
| **Contributor** | Application Insights Component Contributor, Automation Contributor, Monitoring Contributor | Configure Application Insights, create automation runbooks, set up alerts and diagnostic settings |
| **Admin** | Contributor | Full control over monitoring and automation resources |

### Justification

- **Ops teams must set diagnostics, alerts, workspaces, and automation**: Operations teams require comprehensive access to configure monitoring, logging, and automation across all resources.

- **Log Analytics Contributor for log management**: Operators can write logs, create custom queries, and manage log ingestion without needing full workspace contributor access.

- **Application Insights for application monitoring**: Application Insights Component Contributor enables teams to configure application performance monitoring, set up availability tests, and manage application insights resources.

- **Automation Contributor for runbooks**: Teams can create and manage Azure Automation runbooks for operational tasks and remediation.

- **Monitoring Contributor for alerting**: Monitoring Contributor allows configuration of metric alerts, activity log alerts, and diagnostic settings across resources.

- **Separation of read vs write**: Viewers can read logs and metrics, operators can write logs, and contributors can configure all monitoring and automation resources.

---

## Access Level Summary

| Access Level | Typical Use Case | Common Roles |
|-------------|------------------|--------------|
| **Viewer** | Audit, compliance, troubleshooting, FinOps | Reader, Security Reader, Log Analytics Reader, Monitoring Reader |
| **Operator** | Day-to-day operations, running services | Managed Identity Operator, Virtual Machine User Login, Logic App Operator, Log Analytics Contributor |
| **Contributor** | Resource management, deployment, configuration | Service-specific contributors (Network Contributor, Virtual Machine Contributor, etc.) |
| **Admin** | Infrastructure provisioning, access management | Contributor, User Access Administrator, Security Admin |

---

## Capability Group Naming Convention

All capability groups follow the pattern: `rai-<capability>-<level>`

Examples:
- `rai-compute-contributor`
- `rai-data-viewer`
- `rai-network-admin`
- `rai-security-operator`

**Note**: Access isolation is controlled by **RBAC scope** (resourceGroup vs subscription), not by group name. A single capability group can be assigned different roles at different scopes across multiple projects.

---

*For implementation details, see the [Identity System Review](IDENTITY-SYSTEM-REVIEW.md) and [Quick Start Guide](QUICK-START.md).*
