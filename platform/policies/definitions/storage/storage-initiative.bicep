targetScope = 'managementGroup'

param initiativeName string = 'storage-baseline'
param displayName string = 'Storage Baseline'
param description string = 'Baseline storage security guardrails using built-in policies aligned with ASB Storage domain.'
param category string = 'Storage'

@allowed(['Audit', 'Deny', 'Disabled'])
param effect string = 'Deny'

// Some storage policies only allow Audit/Disabled. Provide a dedicated parameter.
@allowed(['Audit', 'Disabled'])
param auditOnlyEffect string = 'Audit'

resource policySet 'Microsoft.Authorization/policySetDefinitions@2023-04-01' = {
  name: initiativeName
  properties: {
    policyType: 'Custom'
    displayName: displayName
    description: description
    metadata: {
      category: category
      version: '1.1.0'
      source: 'ASB: Storage'
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policies'
        }
        allowedValues: ['Audit', 'Deny', 'Disabled']
        defaultValue: effect
      }
      auditOnlyEffect: {
        type: 'String'
        metadata: {
          displayName: 'Audit-only Effect'
          description: 'Effect for policies that only support Audit or Disabled'
        }
        allowedValues: ['Audit', 'Disabled']
        defaultValue: auditOnlyEffect
      }
    }
    policyDefinitions: [
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9'
        policyDefinitionReferenceId: 'SecureTransferRequired'
        groupNames: ['storage']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/4fa4b6c0-31ca-4c0d-b10d-24b96f62a751'
        policyDefinitionReferenceId: 'DisallowPublicBlobAccess'
        groupNames: ['storage']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/6fac406b-40ca-413b-bf8e-0bf964659c25'
        policyDefinitionReferenceId: 'StorageUseCMK'
        groupNames: ['storage']
        parameters: {
          effect: {
            value: '[parameters(\'auditOnlyEffect\')]'
          }
        }
      }
      {
        policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/37e0d2fe-28a5-43d6-a273-67d37d1f5606'
        policyDefinitionReferenceId: 'MigrateToARM'
        groupNames: ['storage']
        parameters: {
          effect: {
            value: '[parameters(\'effect\')]'
          }
        }
      }
      // NOTE: Storage private endpoint policy requires privateEndpointSubnetId parameter
      // This is a DeployIfNotExists policy that needs infrastructure-specific subnet ID
      // Uncomment and add privateEndpointSubnetId parameter after configuring subnet IDs
      // {
      //   policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/9f766f00-8d11-464e-80e1-4091d7874074'
      //   policyDefinitionReferenceId: 'StoragePrivateEndpoint'
      //   groupNames: ['storage']
      //   parameters: {
      //     effect: {
      //       value: '[parameters(\'auditOnlyEffect\')]'
      //     }
      //     privateEndpointSubnetId: {
      //       value: '<subnet-resource-id>' // Requires infrastructure-specific subnet ID
      //     }
      //   }
      // }
    ]
    policyDefinitionGroups: [
      {
        name: 'storage'
        displayName: 'Storage Security baseline'
        description: 'Policies enforcing HTTPS, CMK encryption, preventing public blob access, and requiring private endpoints'
      }
    ]
  }
}
