targetScope = 'managementGroup'

@description('Name of the initiative (policy set definition).')
param initiativeName string = 'network-baseline'

@description('Display name for the initiative.')
param displayName string = 'Network Baseline'

@description('Description for the initiative.')
param initiativeDescription string = 'Baseline network security guardrails using built-in policies aligned with ASB Network Security domain.'

@description('ASB domain category.')
param category string = 'Network'

@description('Effect for policies that only support AuditIfNotExists/Disabled.')
@allowed(['AuditIfNotExists', 'Disabled'])
param auditIfNotExistsEffect string = 'AuditIfNotExists'

resource policySet 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: initiativeName
  properties: {
    policyType: 'Custom'
    displayName: displayName
    description: initiativeDescription
    metadata: {
      category: category
      version: '1.0.0'
      source: 'ASB: Network Security'
    }
    parameters: {
      auditIfNotExistsEffect: {
        type: 'String'
        metadata: {
          displayName: 'AuditIfNotExists Effect'
          description: 'Effect for policies that support AuditIfNotExists/Disabled only'
        }
        allowedValues: ['AuditIfNotExists', 'Disabled']
        defaultValue: auditIfNotExistsEffect
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/e71308d3-144b-4262-b144-efdc3cc90517'
        policyDefinitionReferenceId: 'SubnetsAssociatedWithNSG'
        groupNames: ['network']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/bb91dfba-c30d-4263-9add-9c2384e659a6'
        policyDefinitionReferenceId: 'NonInternetVMsProtectedByNSG'
        groupNames: ['network']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/a7aca53f-2ed4-4466-a25e-0b45ade68efd'
        policyDefinitionReferenceId: 'DDoSProtectionEnabled'
        groupNames: ['network']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/b0f33259-77d7-4c9e-aac6-3aabcfae693c'
        policyDefinitionReferenceId: 'JITNetworkAccess'
        groupNames: ['network']
        parameters: {
          effect: {
            value: '[parameters(\'auditIfNotExistsEffect\')]'
          }
        }
      }
    ]
    policyDefinitionGroups: [
      {
        name: 'network'
        displayName: 'Network Security baseline'
        description: 'Policies enforcing network segmentation, NSGs, DDoS protection, and JIT access'
      }
    ]
  }
}
