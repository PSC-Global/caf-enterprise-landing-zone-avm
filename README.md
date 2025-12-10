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

##  How to Use This Repository

This repository provides the Bicep templates and structure required to deploy the foundational **CAF-aligned management group hierarchy** using Azure Verified Modules (AVM).

Follow the steps below to deploy the hierarchy into your Azure tenant.

---

### **1. Login to the Correct Tenant**

Clear any previous sessions:

```bash
az account clear
```

Login:

```bash
az login --tenant <YourTenantID>
```

> ⚠️ Replace `<YourTenantID>` with your actual tenant ID.  
> Do **not** share this publicly.

---

### **2. Validate the Bicep Template (Optional but Recommended)**

Validate syntax, module versions, and ensure AVM dependencies resolve:

```bash
az bicep build --file platform/management/mg-rai.bicep
```

If the AVM version is invalid, you will see:

```
Error BCP192: The artifact does not exist in the registry.
```

---

### **3. Deploy the Management Group Hierarchy**

```bash
az deployment mg create   --management-group-id <TenantRootGroupId>   --template-file platform/management/mg-rai.bicep   --name rai-mg-bootstrap   --location australiaeast
```

> 💡 **Tip:** Management groups deploy asynchronously.  
> Azure Portal may take **30–90 seconds** to display the full hierarchy.

---

### **4. Verify Deployment**

```bash
az deployment mg show --name rai-mg-bootstrap
```

Then check Azure Portal → **Management Groups**.

Expected structure:

```
/rai
  /platform
  /landing-zones
  /sandbox
```

---

### **5. (Optional) Redeploy or Clean Up**

Redeploy (safe & idempotent):

```bash
az deployment mg create   --management-group-id <TenantRootGroupId>   --template-file platform/management/mg-rai.bicep   --name rai-mg-bootstrap
```

Delete deployment record (not the MGs):

```bash
az deployment mg delete --name rai-mg-bootstrap
```

---

##  Upcoming Additions

- Identity & RBAC patterns  
- Logging & diagnostics baseline  
- Network topology (hub/spoke or vWAN)  
- Policy initiatives  
- Subscription vending  
- Application landing zones  
- DevSecOps and APIM/AKS/Foundry foundations  




