#Requires -Version 7.0
<#
.SYNOPSIS
    Azure deployment and resource discovery helper functions

.DESCRIPTION
    Provides functions for Azure resource lookups, deployment operations,
    and subscription resolution. This module handles all direct Azure API interactions.
#>

# Import Common module for Write-Log
$modulePath = Join-Path $PSScriptRoot "Connectivity.Common.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force -ErrorAction SilentlyContinue
}

# Resource Lookup
function Get-HubResourceId {
    <#
    .SYNOPSIS
        Gets the resource ID of a virtual hub
    
    .DESCRIPTION
        Queries Azure to retrieve the resource ID of an existing virtual hub.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$HubName
    )
    
    try {
        $hub = az network vhub show `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $HubName `
            --query id -o tsv 2>$null
        
        if ($hub) {
            return $hub
        }
    }
    catch {
        Write-Log "Failed to get hub resource ID: $_" -Level "WARN"
    }
    
    return $null
}

function Get-ExistingDeploymentOutputs {
    <#
    .SYNOPSIS
        Retrieves outputs from an existing deployment by name pattern
    
    .DESCRIPTION
        Queries Azure deployments to find the latest deployment matching a pattern
        and returns its outputs. Used for dependency resolution between stages.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$DeploymentNamePattern
    )
    
    try {
        $deployments = az deployment group list `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --query "[?contains(name, '$DeploymentNamePattern')]" -o json 2>$null | ConvertFrom-Json
        
        if ($deployments) {
            $latest = $deployments | Sort-Object -Property properties.timestamp -Descending | Select-Object -First 1
            if ($latest -and $latest.properties.outputs) {
                return $latest.properties.outputs
            }
        }
    }
    catch {
        Write-Log "Failed to retrieve deployment outputs: $_" -Level "WARN"
    }
    
    return $null
}

function Get-ExistingResourceId {
    <#
    .SYNOPSIS
        Gets the resource ID of an existing Azure resource
    
    .DESCRIPTION
        Queries Azure to retrieve the resource ID of an existing resource by type and name.
        Used for hard dependency checks in stage-based deployments.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$ResourceType,
        
        [Parameter(Mandatory)]
        [string]$ResourceName
    )
    
    try {
        $resourceId = az resource show `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --resource-type $ResourceType `
            --name $ResourceName `
            --query id -o tsv 2>$null
        
        if ($resourceId) {
            return $resourceId
        }
    }
    catch {
        # Resource doesn't exist or not found
    }
    
    return $null
}

function Get-LogAnalyticsWorkspaceId {
    <#
    .SYNOPSIS
        Gets the Log Analytics Workspace ID from the central logging subscription
    
    .DESCRIPTION
        Resolves the central Log Analytics Workspace ID from the platform-logging subscription.
        Used for diagnostic settings configuration.
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$WorkspaceName = "law-rai-prod-aue-platform-01",
        
        [Parameter(Mandatory = $false)]
        [string]$ResourceGroup = "rg-rai-prod-aue-logging-01",
        
        [Parameter(Mandatory = $false)]
        [string]$LoggingSubscriptionAlias = "rai-platform-logging-prod-01"
    )
    
    $platformLoggingSub = $Config.subscriptions | Where-Object { $_.aliasName -eq $LoggingSubscriptionAlias } | Select-Object -First 1
    
    if (!$platformLoggingSub) {
        return $null
    }
    
    try {
        $platformLoggingSubId = az rest --method GET `
            --uri "https://management.azure.com/providers/Microsoft.Subscription/aliases/$($platformLoggingSub.aliasName)?api-version=2021-10-01" `
            --query "properties.subscriptionId" -o tsv 2>$null
        $platformLoggingSubId = Normalize-SubscriptionId -SubscriptionId $platformLoggingSubId
    }
    catch {
        return $null
    }
    
    if (!$platformLoggingSubId) {
        return $null
    }
    
    try {
        $laWorkspaceId = (az monitor log-analytics workspace show `
            --subscription $platformLoggingSubId `
            --resource-group $ResourceGroup `
            --workspace-name $WorkspaceName `
            --query id -o tsv 2>$null)
        
        if ($laWorkspaceId) {
            Write-Log "Using central Log Analytics Workspace: $WorkspaceName" -Level "SUCCESS"
            return $laWorkspaceId
        }
    }
    catch {
        Write-Log "Failed to retrieve Log Analytics workspace: $_" -Level "WARN"
    }
    
    return $null
}

function Resolve-SubscriptionIdFromAlias {
    <#
    .SYNOPSIS
        Resolves Azure subscription ID from subscription alias using REST API
    
    .DESCRIPTION
        Uses Azure REST API to resolve subscription ID from alias name.
        This is the same method used in deploy-mg-alias.ps1.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$AliasName
    )
    
    try {
        # Construct URI explicitly to avoid PowerShell string interpolation issues
        $uri = "https://management.azure.com/providers/Microsoft.Subscription/aliases/$($AliasName)?api-version=2021-10-01"
        
        # Capture both stdout and stderr to see what's happening
        $azOutput = az rest --method GET `
            --uri $uri `
            --query "properties.subscriptionId" -o tsv 2>&1
        
        $exitCode = $LASTEXITCODE
        
        # Stringify output for logging
        $azText = ($azOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($azText)) {
            $azText = "(no output)"
        }
        
        if ($exitCode -ne 0) {
            Write-Log "Failed to resolve subscription alias '$AliasName'. Azure CLI returned exit code $exitCode" -Level "WARN"
            Write-Log "Azure CLI output: $azText" -Level "WARN"
            return $null
        }
        
        # Extract subscription ID from output (handle both string and array outputs)
        $subId = if ($azOutput -is [string]) {
            $azOutput.Trim()
        } elseif ($azOutput -is [array] -and $azOutput.Count -gt 0) {
            # Filter out error messages, get the actual subscription ID
            ($azOutput | Where-Object { $_ -match '^[0-9a-fA-F-]{36}$' } | Select-Object -First 1)
        } else {
            $null
        }
        
        # Normalize and validate the subscription ID
        if ([string]::IsNullOrWhiteSpace($subId)) {
            Write-Log "Subscription alias '$AliasName' returned empty subscription ID. Output was: $azText" -Level "WARN"
            return $null
        }
        
        $subId = $subId.Trim()
        $normalizedSubId = Normalize-SubscriptionId -SubscriptionId $subId
        
        if ($normalizedSubId -and $normalizedSubId -match '^[0-9a-fA-F-]{36}$') {
            Write-Log "Resolved subscription alias '$AliasName' to ID: $normalizedSubId" -Level "INFO"
            return $normalizedSubId
        }
        
        Write-Log "Subscription alias '$AliasName' resolved to invalid format: $subId" -Level "WARN"
        return $null
    }
    catch {
        Write-Log "Exception resolving subscription alias '$AliasName': $_" -Level "WARN"
        return $null
    }
}

function Ensure-ResourceGroup {
    <#
    .SYNOPSIS
        Ensures a resource group exists, creating it if necessary
    
    .DESCRIPTION
        Checks if a resource group exists and creates it using Bicep if it doesn't.
        This is idempotent - safe to call multiple times.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$Location,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory)]
        [string]$PrimaryRegion,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionPurpose,
        
        [Parameter(Mandatory)]
        [object]$Tags,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionAlias,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would create networking resource group: $ResourceGroupName" -Level "WARN"
        return
    }
    
    try {
        Restore-BicepModules -BicepFile "../bicep/resource-group.bicep"
        
        $rgParams = @(
            "primaryRegion=$PrimaryRegion",
            "subscriptionPurpose=$SubscriptionPurpose",
            "tags=$($Tags | ConvertTo-Json -Compress)"
        )
        
        # Check if resource group already exists
        $rgExists = az group show --name $ResourceGroupName --subscription $SubscriptionId --query "name" -o tsv 2>$null
        
        if ($rgExists) {
            Write-Log "Networking resource group already exists: $ResourceGroupName" -Level "INFO"
            return
        }
        
        $rgDeploymentName = "rg-network-$SubscriptionAlias-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        az deployment sub create `
            --subscription $SubscriptionId `
            --location $Location `
            --name $rgDeploymentName `
            --template-file "../bicep/resource-group.bicep" `
            --parameters $rgParams `
            --output json | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Resource group deployment failed with exit code $LASTEXITCODE"
        }
        
        Write-Log "Networking resource group created: $ResourceGroupName" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to create networking resource group: $_" -Level "ERROR"
        throw
    }
}

Export-ModuleMember -Function Get-HubResourceId, Get-ExistingDeploymentOutputs, Get-ExistingResourceId, `
    Get-LogAnalyticsWorkspaceId, Resolve-SubscriptionIdFromAlias, Ensure-ResourceGroup
