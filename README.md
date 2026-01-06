
# CAF Enterprise Landing Zone (AVM + Bicep)

This repository contains the enterprise landing zone foundation using the Microsoft Cloud Adoption Framework (CAF), Azure Verified Modules (AVM), and Bicep. It provides a governance-first, scalable Azure platform scaffold suitable for enterprise adoption.

---

## Current Scope

- Management group hierarchy and baseline platform modules
- Foundational Bicep templates for management, identity, connectivity, logging, and policies
- Subscription vending machine for automated subscription provisioning and bootstrap

This repo is organised to support progressive blog posts and practical deployments; see the `platform`, `subscription-vending`, and `landing-zones` folders for source templates.

---

## Repository Structure

```
platform/
  management/
  identity/
  connectivity/
  logging/
  policies/
subscription-vending/
landing-zones/


```

---

## Documentation & How to Use This Repository (task-focused)

  ---

  ## 1 — Management groups

  What it is: the authoritative management group hierarchy used by this landing zone (RAI → platform → landing-zones → sandbox).

  Where to create & deploy: `platform/management/mg-rai.bicep` (see `platform/management/*` for templates and guidance).

  ## 2 — Azure AD groups & identities

  What it is: capability-driven AAD group creation and RBAC assignment pipeline that converts capability/project YAML into AAD groups and role assignments.

  Where to implement: `platform/identity/docs/IDENTITY-SYSTEM-REVIEW.md` and `platform/identity/docs/QUICK-START.md` (see `platform/identity/scripts/` and `platform/identity/bicep/` for pipeline and templates).

  ## 3 — Policies

  What it is: initiative definitions, archetypes and assignment patterns implementing Azure Security Benchmark (ASB) across the hierarchy.

  Where to author & deploy: `platform/policies/docs/README.md`, `platform/policies/docs/DEPLOYMENT-GUIDE.md`, and `platform/policies/docs/POLICY-REFERENCE-GUIDE.md` (see `platform/policies/bicep/` and `platform/policies/scripts/` for templates and automation).

  ## 4 — Subscription Vending

  What it is: automated subscription provisioning and bootstrap pipeline that creates Azure subscriptions via MCA Subscription Alias API, associates them with management groups, and deploys foundational resources (logging, diagnostics, governance).

  Where to deploy: `subscription-vending/docs/README.md`, `subscription-vending/docs/PREREQUISITES.md`, and `subscription-vending/docs/DEPLOYMENT-GUIDE.md` (see `subscription-vending/scripts/` for deployment automation and `subscription-vending/config/` for subscription configuration).

 


