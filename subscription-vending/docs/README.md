# Subscription Vending Machine

Enterprise-grade Azure subscription provisioning for CAF Landing Zones using Azure Verified Modules (AVM).

## Overview

This subscription vending machine automates the creation and configuration of Azure subscriptions across management group hierarchies with foundational resources, diagnostics, and governance controls.

## Features

- **Automated Subscription Provisioning**: Creates subscriptions via MCA Subscription Alias API
- **Management Group Association**: Places subscriptions in correct MG hierarchy
- **Foundational Bootstrap**: Logging resource group, Log Analytics workspace, diagnostic settings
- **Governance Integration**: Automatic policy archetype assignment and RBAC role assignments
- **Multi-Region Support**: Australia East (primary), Australia Southeast (secondary)
- **DR Modes**: Active-active or active-passive per subscription (optional DR subscription)
- **Compliance Ready**: Integrated with policy archetypes and RBAC automation
- **Enterprise-Grade**: Uses Azure Verified Modules, professional error handling
- **Separation of Concerns**: Domain-specific resources deployed via separate pipelines

## Repository Structure

```
subscription-vending/
├── config/
│   ├── subscriptions.json           # Source of truth for subscriptions (minimal structure)
│   └── subscriptions.schema.json     # JSON schema validation
├── mg-orchestration/
│   ├── create-alias.bicep            # Subscription creation via MCA alias
│   └── move-to-mg.bicep              # MG association
├── sub-bootstrap/
│   └── logging/
│       ├── resource-group.bicep      # Logging resource group
│       ├── la-workspace.bicep         # Log Analytics workspace
│       └── diag-settings-subscription.bicep  # Diagnostic settings
├── scripts/
│   ├── deploy-mg-alias.ps1           # Phase 1: Create subscription + MG placement
│   └── deploy-subscription.ps1       # Phase 2: Bootstrap foundational resources + governance
└── docs/
    ├── README.md                     # This file
    ├── PREREQUISITES.md              # Setup requirements
    └── DEPLOYMENT-GUIDE.md           # Step-by-step deployment
```

## Prerequisites

Before using the subscription vending machine, ensure you have:

- Microsoft Customer Agreement (MCA) with billing scope configured
- Azure permissions (Owner at root MG, Subscription Creator on billing)
- Management group hierarchy created
- Policy framework deployed
- AAD groups created for RBAC

See [PREREQUISITES.md](PREREQUISITES.md) for complete setup requirements.

## Architecture

### Subscription-Vending Scope (Foundational Bootstrap)

Subscription-vending focuses on **foundational subscription setup** only:

1. **Subscription Creation**: Create subscription via MCA alias API
2. **Management Group Association**: Place subscription in correct MG hierarchy
3. **Foundational Resources**:
   - Logging resource group
   - Log Analytics workspace
   - Diagnostic settings
4. **Governance**: Apply policy archetypes and RBAC role assignments

## Quick Start

1. **Configure** subscription in `config/subscriptions.json`
2. **Deploy** using scripts in `scripts/` directory
3. **Verify** deployment in Azure Portal

See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for complete step-by-step deployment instructions.

## Deployment Phases

The subscription vending process consists of two main phases:

**Phase 1: Subscription Creation** (`mg-orchestration/`)
- Creates subscription via MCA Subscription Alias API
- Associates subscription with target management group
- Script: `scripts/deploy-mg-alias.ps1`

**Phase 2: Subscription Bootstrap** (`sub-bootstrap/`)
- Creates foundational resource groups
- Deploys Log Analytics workspace
- Configures diagnostic settings
- Script: `scripts/deploy-subscription.ps1`

See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for detailed deployment steps.

## Integration Points

The subscription vending machine integrates with:

- **Policy Framework** (`platform/policies/`): Assigns policy archetypes to subscriptions based on `archetype` field
- **Identity Framework** (`platform/identity/`): Configures RBAC using `ownerAadGroup` from subscription config
- **Management Groups** (`platform/management/`): Places subscriptions in correct MG hierarchy

See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for integration deployment steps.


## Support

For issues or questions:
- Review [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for detailed workflows
- Check [PREREQUISITES.md](PREREQUISITES.md) for setup requirements
