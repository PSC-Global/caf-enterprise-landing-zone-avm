# 📘 CAF Enterprise Landing Zone (AVM + Bicep)

This repository contains the **enterprise landing zone foundation** built using:

- **Microsoft Cloud Adoption Framework (CAF)**
- **Azure Verified Modules (AVM)**
- **Bicep** (infrastructure-as-code)

The goal is to build a **scalable, secure, governance-first Azure platform** following Microsoft’s Enterprise-Scale design principles.

This repo will evolve progressively as the blog series continues.

---

##  Current Scope (Part 1)

**☑ Management Group hierarchy using AVM**

- `/platform`
- `/landing-zones`
- `/sandbox`
- Platform sub-MGs: management, identity, connectivity
- Landing zone sub-MGs: corp, online

This provides the **governance and inheritance foundation** for all future components.

---

##  Repository Structure

```
/platform
  /management
  /identity
  /connectivity
  /logging
  /policies
/workloads
/scripts
/docs
```

As the series continues, each section will be populated with Bicep, policies, and platform components.

---

##  Upcoming Additions

- Identity & RBAC patterns  
- Logging & diagnostics baseline  
- Network topology (hub/spoke or vWAN)  
- Policy initiatives  
- Subscription vending  
- Application landing zones  
- DevSecOps and APIM/AKS/Foundry foundations  

---


