#
# Module manifest for module 'Connectivity'
# Root module that imports all connectivity deployment modules
#

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'Connectivity.psm1'

    # Version number of this module
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'CAF Enterprise Landing Zone'

    # Company or vendor of this module
    CompanyName = 'RAI Consultancy'

    # Copyright statement for this module
    Copyright = '(c) 2024. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'CAF-aligned connectivity deployment modules for Azure Virtual WAN hub and spoke networking'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Modules that must be imported into the global environment prior to importing this module
    # NestedModules = @()

    # Functions to export from this module (public API - only what orchestrator uses)
    FunctionsToExport = @(
        # Common utilities (used by orchestrator)
        'Write-Log'
        'Normalize-SubscriptionId'
        'Get-ConnectivityConfig'
        
        # Azure deployment helpers (used by orchestrator)
        'Get-HubResourceId'
        'Get-ExistingResourceId'
        'Get-LogAnalyticsWorkspaceId'
        'Resolve-SubscriptionIdFromAlias'
        'Ensure-ResourceGroup'
        
        # Diagnostics (used by orchestrator)
        'Ensure-DiagnosticSettings'
        
        # IPAM (used by orchestrator)
        'Get-IpamConfig'
        'Resolve-IpamBlock'
        'Invoke-IpamAllocation'
        'Get-SubnetBlueprint'
        'Generate-Subnets'
        
        # Stage deployments (used by orchestrator)
        'Deploy-HubCore'
        'Deploy-FirewallPolicy'
        'Deploy-Firewall'
        'Deploy-Routing'
        'Deploy-PrivateDns'
        'Deploy-VwanHub'
        'Deploy-SpokeVnet'
        'Invoke-HubDeployment'
        'Invoke-SpokeDeployment'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            Tags = @('Azure', 'Networking', 'vWAN', 'CAF', 'Bicep')
            LicenseUri = ''
            ProjectUri = ''
            IconUri = ''
            ReleaseNotes = 'Initial module structure for CAF-aligned connectivity deployments'
        }
    }
}
