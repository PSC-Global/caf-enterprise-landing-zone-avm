# Azure Security Benchmark - Network Security Domain Control Mapping

## Overview
This document maps Azure Security Benchmark v3 network security controls to built-in policy definitions. Use this as a reference for understanding ASB network requirements and planning phased enforcement across platform connectivity and landing zones.

## Control Family: Network Security (NS)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| NS-1 | Establish network segmentation boundaries | Implement network segmentation using VNets, subnets, and NSGs | NSG required on subnets, deny peering to unauthorized VNets | Platform Connectivity: Enforce, LZ MGs: Phase 1 |
| NS-2 | Secure cloud services with network controls | Secure PaaS services using private endpoints and service endpoints | Require private endpoints for PaaS services | Platform Connectivity: Enforce, Corp LZ: Phase 1, Online LZ: Phase 2 |
| NS-3 | Deploy firewall at the edge of enterprise network | Implement Azure Firewall or partner NVA for internet egress | Require Azure Firewall in hub VNet | Platform Connectivity: Enforce |
| NS-4 | Deploy intrusion detection/prevention systems | Implement IDS/IPS using Azure Firewall Premium or partner solutions | Enable threat intelligence on Azure Firewall | Platform Connectivity: Phase 1, LZ MGs: N/A |
| NS-5 | Deploy DDoS protection | Enable DDoS Protection Standard on virtual networks | Require DDoS Standard on VNets | Platform Connectivity: Enforce, Corp LZ: Audit, Online LZ: Enforce |
| NS-6 | Deploy web application firewall | Protect web applications using Azure WAF or partner solutions | Require WAF on Application Gateway, Front Door | Online LZ: Enforce, Corp LZ: Phase 2 |
| NS-7 | Simplify network security configuration | Use Azure Firewall Manager and centralized network policies | Centralized firewall policy management | Platform Connectivity: Enforce |
| NS-8 | Detect and disable insecure services and protocols | Block or alert on insecure protocols (SMB, RDP from internet) | Deny RDP/SSH from internet, block legacy protocols | All MGs: Enforce |
| NS-9 | Connect on-premises or cloud network privately | Use ExpressRoute or VPN for hybrid connectivity | Require encrypted connections, BGP for routing | Platform Connectivity: Enforce |
| NS-10 | Ensure Domain Name System (DNS) security | Implement Azure DNS Private Zones and DNS security | Use Azure DNS, enable DNS query logging | Platform Connectivity: Enforce, LZ MGs: Phase 1 |

## Control Family: Network Perimeter Security (NP)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| NP-1 | Define network security perimeter | Clearly define and implement network security perimeters | Hub-spoke topology enforcement | Platform Connectivity: Enforce |
| NP-2 | Secure network ingress and egress | Control and monitor all inbound and outbound network traffic | NSG flow logs, firewall logs to Log Analytics | Platform Connectivity: Enforce, LZ MGs: Phase 1 |
| NP-3 | Encrypt network traffic | Use encryption for network traffic (TLS, IPsec, private links) | Require TLS 1.2+, IPsec for VPN | All MGs: Enforce |
| NP-4 | Disable or restrict public network access | Disable public endpoints where not required | Deny public IP on NICs (exceptions managed), require private endpoints | Corp LZ: Enforce, Online LZ: Audit |

## Control Family: Traffic Filtering (TF)

| Control ID | Control Name | Description | Built-In Policy | Enforcement Recommendation |
|------------|--------------|-------------|-----------------|----------------------------|
| TF-1 | Implement network traffic filtering | Use NSGs and Azure Firewall for traffic filtering | NSG required on all subnets | All MGs: Enforce |
| TF-2 | Use threat intelligence-based filtering | Enable threat intelligence in Azure Firewall | Enable threat intelligence on Azure Firewall | Platform Connectivity: Enforce |
| TF-3 | Implement service-specific filtering | Configure application-level filtering (WAF, API Management) | WAF enabled on AppGW/Front Door | Online LZ: Enforce, Corp LZ: Phase 2 |

## Phased Enforcement Strategy

### Phase 1: Core Network Security (Immediate - Platform Connectivity)
- NS-1: Network segmentation
- NS-2: Private endpoints (platform services)
- NS-3: Azure Firewall deployment
- NS-5: DDoS protection
- NS-8: Block insecure protocols
- NS-9: Hybrid connectivity encryption
- NS-10: DNS security
- NP-1: Security perimeter definition
- NP-2: Traffic monitoring
- NP-3: Encryption requirements
- TF-1: Traffic filtering with NSGs

### Phase 2: Landing Zone Network Security (30-60 days)
- NS-1: Network segmentation (LZ enforcement)
- NS-2: Private endpoints (workload services)
- NS-5: DDoS protection (Corp LZ)
- NS-10: DNS integration
- NP-2: Landing zone traffic monitoring
- NP-4: Public access restrictions (Corp LZ)
- TF-3: Service-specific filtering

### Phase 3: Advanced Network Security (60-90 days)
- NS-4: IDS/IPS deployment
- NS-6: WAF deployment (Corp LZ)
- NP-4: Public access restrictions (Online LZ)

## Management Group Specific Guidance

### Platform Connectivity
- **Enforcement Priority**: Critical
- **Initial Mode**: Enforce (all core networking controls)
- **Target Compliance**: 100% within 14 days
- **Key Requirements**:
  - Hub VNet with Azure Firewall
  - DDoS Standard enabled
  - ExpressRoute/VPN with encryption
  - Azure DNS Private Zones
  - Centralized firewall policies
  - NSG flow logs to Log Analytics

### Corp Landing Zones
- **Enforcement Priority**: High
- **Initial Mode**: Enforce (NS-1, NS-8, TF-1), Audit others
- **Target Compliance**: 95% within 60 days
- **Key Requirements**:
  - Spoke VNets peered to hub
  - Private endpoints for PaaS
  - No direct internet egress (via Azure Firewall)
  - NSGs on all subnets
  - No public IPs on NICs (exceptions via exemption)
  - DDoS Standard on critical workloads

### Online Landing Zones
- **Enforcement Priority**: High (internet-facing)
- **Initial Mode**: Enforce (NS-5, NS-6, NS-8, TF-1), Audit others
- **Target Compliance**: 90% within 60 days
- **Key Requirements**:
  - WAF on all Application Gateways/Front Door
  - DDoS Standard on all VNets
  - NSGs on all subnets
  - TLS 1.2+ enforcement
  - Private endpoints for backend services
  - Public IPs allowed with restrictions

### Platform Identity & Management
- **Network Scope**: Limited
- **Enforcement Priority**: Medium
- **Initial Mode**: Audit
- **Key Requirements**:
  - Private endpoints for Key Vault, Storage
  - Network isolation for management services
  - No direct public access

## Network Architecture Patterns

### Hub-Spoke Topology
```
Hub VNet (Platform Connectivity)
├── Azure Firewall Subnet
├── Gateway Subnet (ExpressRoute/VPN)
├── Azure Bastion Subnet
└── Management Subnet

Spoke VNets (Landing Zones)
├── App Tier Subnet (with NSG)
├── Data Tier Subnet (with NSG)
└── Private Endpoint Subnet
```

### Traffic Flow Requirements
1. **Ingress**: Internet → WAF/AppGW → Private Endpoint → Workload
2. **Egress**: Workload → Route Table → Azure Firewall → Internet
3. **East-West**: Spoke → Hub Firewall → Spoke (with policy enforcement)
4. **Hybrid**: On-premises → ExpressRoute/VPN → Hub → Spoke

## Common Exemption Scenarios

### Approved Public IP Use Cases
- Azure Bastion (platform management)
- Public Load Balancers (internet-facing apps)
- Application Gateway/Front Door (with WAF)
- VPN Gateway

### Private Endpoint Exemptions
- Services not supporting private endpoints
- Development/test environments (temporary, with expiration)
- Third-party SaaS integrations

## References
- [Azure Network Security Best Practices](https://learn.microsoft.com/en-us/azure/security/fundamentals/network-best-practices)
- [Hub-Spoke Network Topology](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Azure Firewall Documentation](https://learn.microsoft.com/en-us/azure/firewall/)
- [Azure DDoS Protection](https://learn.microsoft.com/en-us/azure/ddos-protection/ddos-protection-overview)
