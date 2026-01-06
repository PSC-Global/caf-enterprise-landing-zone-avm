#Requires -Version 7.0
<#
.SYNOPSIS
    Bootstraps a newly created subscription with foundational resources and governance
    
.DESCRIPTION
    Deploys subscription-level foundational resources including:
    - Logging resource group
    - Log Analytics workspace for diagnostics
    - Diagnostic settings for subscription resources
    - Policy archetype assignment (governance)
    - RBAC role assignments (identity)
    
    Note: Networking resources (vWAN hub, spoke vNet) should be deployed separately
    using platform/connectivity/scripts/deploy-connectivity.ps1
    
.PARAMETER ConfigFile
    Path to subscriptions.json configuration file
    
.PARAMETER SubscriptionId
    The subscription ID (aliasName) from the config to bootstrap
    
.PARAMETER SkipDiagnostics
    Skip diagnostic settings deployment
    
.PARAMETER SkipGovernance
    Skip governance deployment (policies and RBAC)
    
.EXAMPLE
    ./deploy-subscription.ps1 -SubscriptionId "rai-platform-management-prod-01" -WhatIf
    
.EXAMPLE
    ./deploy-subscription.ps1 -SubscriptionId "rai-fraud-engine-prod-01"
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "../config/subscriptions.json",
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDiagnostics,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipGovernance
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Capture WhatIf mode
$IsWhatIf = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf')

# =============================================================================
# Helper Functions
# =============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Normalize-SubscriptionId {
    param([string]$SubscriptionId)
    
    if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
        return $null
    }
    
    # If it's a full resource ID path, extract just the GUID
    if ($SubscriptionId -match '^/subscriptions/([0-9a-fA-F-]{36})$') {
        return $Matches[1]
    }
    
    # If it's already just a GUID, return as-is
    if ($SubscriptionId -match '^[0-9a-fA-F-]{36}$') {
        return $SubscriptionId
    }
    
    return $SubscriptionId
}

function Wait-ForSubscription {
    param(
        [string]$SubscriptionId,
        [int]$MaxWaitSeconds = 300
    )
    
    $elapsed = 0
    $interval = 5
    
    while ($elapsed -lt $MaxWaitSeconds) {
        try {
            $sub = az account subscription show --subscription-id $SubscriptionId --query "state" -o tsv 2>$null
            if ($sub -eq "Enabled") {
                Write-Log "Subscription $SubscriptionId is now enabled" -Level "SUCCESS"
                return $true
            }
        }
        catch {
            # Subscription might not be visible yet
        }
        
        Start-Sleep -Seconds $interval
        $elapsed += $interval
        Write-Log "Waiting for subscription to be ready... ($elapsed/$MaxWaitSeconds seconds)" -Level "INFO"
    }
    
    Write-Log "Timeout waiting for subscription to be ready" -Level "WARN"
    return $false
}

function Restore-BicepModules {
    param([string]$BicepFile)
    
    $bicepPath = Join-Path $PSScriptRoot $BicepFile
    if (!(Test-Path $bicepPath)) {
        Write-Log "Bicep file not found: $bicepPath" -Level "WARN"
        return
    }
    
    Write-Log "Restoring Bicep modules for: $BicepFile" -Level "INFO"
    
    Push-Location $PSScriptRoot
    try {
        $restoreOutput = az bicep restore --file $BicepFile 2>&1 | Out-String
        $restoreExitCode = $LASTEXITCODE
        
        if ($restoreExitCode -ne 0) {
            Write-Log "Warning: Bicep module restore failed for $BicepFile (exit code: $restoreExitCode)" -Level "WARN"
            Write-Log "Output: $restoreOutput" -Level "WARN"
            # Don't fail here - the deployment might still work if modules are cached
        } else {
            Write-Log "Bicep modules restored successfully" -Level "SUCCESS"
        }
    }
    finally {
        Pop-Location
    }
}

# =============================================================================
# Load Configuration
# =============================================================================

Write-Log "Loading configuration from $ConfigFile"

if (!(Test-Path $ConfigFile)) {
    Write-Log "Configuration file not found: $ConfigFile" -Level "ERROR"
    exit 1
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json

# Find the subscription entry by aliasName or displayName
$subscription = $config.subscriptions | Where-Object { $_.aliasName -eq $SubscriptionId -or $_.displayName -eq $SubscriptionId }

if (!$subscription) {
    Write-Log "Subscription '$SubscriptionId' not found in configuration (checked aliasName and displayName)" -Level "ERROR"
    exit 1
}

Write-Log "Bootstrapping subscription: $($subscription.displayName)"
Write-Log "Role: $($subscription.role)"
Write-Log "Primary region: $($subscription.primaryRegion)"
Write-Log "Target MG: $($subscription.targetMg)"
Write-Log "Archetype: $($subscription.archetype)"

# Resolve the subscription ID using aliasName via REST API
Write-Log "Resolving Azure Subscription ID for alias: $($subscription.aliasName)"

try {
    $aliasResponse = az rest --method GET `
        --uri "https://management.azure.com/providers/Microsoft.Subscription/aliases/$($subscription.aliasName)?api-version=2021-10-01" `
        --query "properties.subscriptionId" -o tsv 2>$null
    
    $azSubscriptionId = $aliasResponse
}
catch {
    Write-Log "Failed to query subscription alias via REST API: $_" -Level "WARN"
    $azSubscriptionId = $null
}

if ([string]::IsNullOrWhiteSpace($azSubscriptionId)) {
    Write-Log "Could not find Azure subscription for alias '$($subscription.aliasName)'." -Level "ERROR"
    Write-Log "Please ensure the subscription was created via deploy-mg-alias.ps1 first." -Level "ERROR"
    exit 1
}

Write-Log "Resolved Azure Subscription ID: $azSubscriptionId"

# Normalize subscription ID (extract GUID if it's a full resource ID path)
$azSubscriptionId = Normalize-SubscriptionId -SubscriptionId $azSubscriptionId

if ([string]::IsNullOrWhiteSpace($azSubscriptionId)) {
    Write-Log "Could not resolve Azure subscription ID." -Level "ERROR"
    exit 1
}

Write-Log "Using normalized subscription ID: $azSubscriptionId" -Level "INFO"

# Wait for subscription to be ready (if not in WhatIf)
if (!$IsWhatIf) {
    Write-Log "Verifying subscription is ready..."
    Wait-ForSubscription -SubscriptionId $azSubscriptionId -MaxWaitSeconds 60
}

# Refresh Azure CLI account list to ensure newly created subscriptions are available
Write-Log "Refreshing Azure CLI account list..." -Level "INFO"
az account list --refresh 2>&1 | Out-Null

# Set subscription context
Write-Log "Setting Azure CLI context to subscription: $azSubscriptionId" -Level "INFO"
az account set --subscription $azSubscriptionId 2>&1 | Out-Null

# Verify subscription context is set correctly
$currentSub = az account show --query id -o tsv 2>$null
if ($currentSub -ne $azSubscriptionId) {
    Write-Log "Warning: Subscription context may not be set correctly. Current: $currentSub, Expected: $azSubscriptionId" -Level "WARN"
    # Try refreshing again and setting context
    az account list --refresh 2>&1 | Out-Null
    az account set --subscription $azSubscriptionId 2>&1 | Out-Null
    $currentSub = az account show --query id -o tsv 2>$null
    if ($currentSub -ne $azSubscriptionId) {
        Write-Log "Failed to set subscription context. Please verify subscription exists and you have access." -Level "ERROR"
        Write-Log "Subscription ID: $azSubscriptionId" -Level "ERROR"
        exit 1
    }
}

# Derive subscription purpose for naming
$environment = if ($subscription.targetMg -eq "sandbox" -or $subscription.role -eq "sandbox") { "dev" } else { "prod" }
$subscriptionPurpose = switch ($subscription.role) {
    "hub" { "network-core" }
    "platform" { 
        switch ($subscription.targetMg) {
            "platform-management" { "platform-core" }
            "platform-identity" { "identity" }
            "platform-logging" { "secops" }
            default { "platform-core" }
        }
    }
    "workload" {
        if ($subscription.aliasName -match "fraud-engine") { "fraud-engine" }
        elseif ($subscription.aliasName -match "lending-core") { "lending-core" }
        else { "workload" }
    }
    default { "sandbox" }
}

# Initialize variables
$loggingRgName = $null
$laResourceId = $null
$rgDeployment = $null
$laDeployment = $null

# =============================================================================
# Phase 1: Create Logging Resource Group
# =============================================================================

Write-Log "Phase 1: Creating logging resource group" -Level "SUCCESS"

$deploymentName = "rg-logging-$($subscription.aliasName)-$(Get-Date -Format 'yyyyMMddHHmmss')"
$rgParams = @{
    primaryRegion       = $subscription.primaryRegion
    subscriptionPurpose = $subscriptionPurpose
    tags                = $subscription.tags
}

if ($IsWhatIf) {
    Write-Log "WhatIf: Would deploy logging resource-group.bicep to subscription $azSubscriptionId" -Level "WARN"
    Write-Log "Parameters: $($rgParams | ConvertTo-Json -Depth 3)" -Level "WARN"
    $loggingRgName = "rg-$subscriptionPurpose-logging-$($subscription.primaryRegion)-001"
} else {
    try {
        # Restore Bicep modules before deployment
        Restore-BicepModules -BicepFile "../sub-bootstrap/logging/resource-group.bicep"
        
        # Build parameters as key=value pairs
        $rgParamArray = @(
            "primaryRegion=$($rgParams.primaryRegion)",
            "subscriptionPurpose=$($rgParams.subscriptionPurpose)",
            "tags=$($rgParams.tags | ConvertTo-Json -Compress)"
        )
        
        # Deploy resource group
        $rgDeployment = az deployment sub create `
            --subscription $azSubscriptionId `
            --name $deploymentName `
            --location $subscription.primaryRegion `
            --template-file "../sub-bootstrap/logging/resource-group.bicep" `
            --parameters $rgParamArray `
            --output json | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0) {
            throw "Resource group deployment failed with exit code $LASTEXITCODE"
        }
        
        if (!$rgDeployment -or !$rgDeployment.properties -or !$rgDeployment.properties.outputs) {
            Write-Log "Deployment completed but output format is invalid: $($rgDeployment | ConvertTo-Json -Depth 3)" -Level "ERROR"
            throw "Invalid deployment output format"
        }
        
        $loggingRgName = $rgDeployment.properties.outputs.loggingRgName.value
        
        Write-Log "Logging resource group created: $loggingRgName" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to deploy logging resource group: $_" -Level "ERROR"
        Write-Log "Subscription ID used: $azSubscriptionId" -Level "INFO"
        Write-Log "Please verify the subscription exists and you have access to it." -Level "INFO"
        exit 1
    }
}

# =============================================================================
# Phase 2: Deploy Log Analytics Workspace
# =============================================================================

Write-Log "Phase 2: Deploying Log Analytics workspace" -Level "SUCCESS"

$laDeploymentName = "la-$($subscription.aliasName)-$(Get-Date -Format 'yyyyMMddHHmmss')"
$laWorkspaceName = "law-$subscriptionPurpose-$($subscription.primaryRegion)-001"
$laParams = @{
    workspaceName      = $laWorkspaceName
    location           = $subscription.primaryRegion
    tags               = $subscription.tags
    retentionInDays    = if ($environment -eq "prod") { 90 } else { 30 }
    enableDiagnostics  = $false # Self-diagnostics not needed
}

if ($IsWhatIf) {
    Write-Log "WhatIf: Would deploy la-workspace.bicep to RG $loggingRgName" -Level "WARN"
    $laResourceId = "/subscriptions/$azSubscriptionId/resourceGroups/$loggingRgName/providers/Microsoft.OperationalInsights/workspaces/$laWorkspaceName"
} else {
    try {
        if ([string]::IsNullOrWhiteSpace($loggingRgName)) {
            Write-Log "No logging resource group available for Log Analytics workspace deployment" -Level "ERROR"
            throw "No target resource group found"
        }
        
        # Restore Bicep modules before deployment
        Restore-BicepModules -BicepFile "../sub-bootstrap/logging/la-workspace.bicep"
        
        $laParamArray = @(
            "workspaceName=$laWorkspaceName",
            "location=$($laParams.location)",
            "tags=$($laParams.tags | ConvertTo-Json -Compress)",
            "retentionInDays=$($laParams.retentionInDays)",
            "enableDiagnostics=$($laParams.enableDiagnostics)"
        )
        
        $laDeployment = az deployment group create `
            --subscription $azSubscriptionId `
            --resource-group $loggingRgName `
            --name $laDeploymentName `
            --template-file "../sub-bootstrap/logging/la-workspace.bicep" `
            --parameters $laParamArray `
            --output json | ConvertFrom-Json
        
        if ($LASTEXITCODE -ne 0) {
            throw "Log Analytics deployment failed with exit code $LASTEXITCODE"
        }
        
        $laResourceId = $laDeployment.properties.outputs.resourceId.value
        Write-Log "Log Analytics workspace deployed: $laResourceId" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to deploy Log Analytics workspace: $_" -Level "ERROR"
        exit 1
    }
}

# =============================================================================
# Phase 3: Deploy Diagnostic Settings
# =============================================================================

if (!$SkipDiagnostics) {
    Write-Log "Phase 3: Deploying diagnostic settings" -Level "SUCCESS"
    
    $diagDeploymentName = "diag-$($subscription.aliasName)-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $diagParams = @{
        diagnosticSettingName    = "subscription-diagnostics"
        logAnalyticsWorkspaceId  = $laResourceId
        enableAllLogs            = $true
        enableAllMetrics         = $true
    }
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy diag-settings-subscription.bicep for subscription" -Level "WARN"
    } else {
        try {
            # Restore Bicep modules before deployment
            Restore-BicepModules -BicepFile "../sub-bootstrap/logging/diag-settings-subscription.bicep"
            
            $diagParamArray = @(
                "diagnosticSettingName=$($diagParams.diagnosticSettingName)",
                "logAnalyticsWorkspaceId=$($diagParams.logAnalyticsWorkspaceId)",
                "enableAllLogs=$($diagParams.enableAllLogs)",
                "enableAllMetrics=$($diagParams.enableAllMetrics)"
            )
            
            # Diagnostic settings for subscription must be deployed at subscription scope
            az deployment sub create `
                --subscription $azSubscriptionId `
                --name $diagDeploymentName `
                --location $subscription.primaryRegion `
                --template-file "../sub-bootstrap/logging/diag-settings-subscription.bicep" `
                --parameters $diagParamArray `
                --output json | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                throw "Diagnostic settings deployment failed with exit code $LASTEXITCODE"
            }
            
            Write-Log "Diagnostic settings deployed for subscription" -Level "SUCCESS"
        }
        catch {
            Write-Log "Failed to deploy diagnostic settings: $_" -Level "ERROR"
            # Don't exit - diagnostic settings are optional
        }
    }
} else {
    Write-Log "Skipping diagnostic settings deployment (--SkipDiagnostics specified)" -Level "WARN"
}

# =============================================================================
# Phase 4: Apply Governance (Policies and RBAC)
# =============================================================================

if (!$SkipGovernance) {
    Write-Log "Phase 4: Applying governance (policies and RBAC)" -Level "SUCCESS"
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would apply policy archetype and RBAC assignments" -Level "WARN"
    } else {
        # Apply policy archetype
        if ($subscription.archetype) {
            Write-Log "Applying policy archetype: $($subscription.archetype)" -Level "INFO"
            
            $archetypeScript = "../../platform/policies/scripts/assign-sub-archetype.sh"
            if (Test-Path $archetypeScript) {
                try {
                    # Map archetype name to archetype file path
                    $archetypeFile = switch ($subscription.archetype) {
                        "platform-connectivity" { "../../platform/policies/archetypes/platform-connectivity/prod.json" }
                        "platform-management" { "../../platform/policies/archetypes/platform-management/prod.json" }
                        "platform-identity" { "../../platform/policies/archetypes/platform-identity/prod.json" }
                        "platform-logging" { "../../platform/policies/archetypes/platform-logging/prod.json" }
                        "online-workload" { "../../platform/policies/archetypes/online/prod.json" }
                        "corp" { "../../platform/policies/archetypes/corp/prod.json" }
                        "sandbox" { "../../platform/policies/archetypes/corp/nonprod.json" }
                        default { "../../platform/policies/archetypes/$($subscription.archetype)/prod.json" }
                    }
                    
                    # Set subscription context first
                    az account set --subscription $azSubscriptionId | Out-Null
                    
                    # Call script with positional parameters: location, archetypeName, archetypeFile, module
                    bash $archetypeScript $subscription.primaryRegion $subscription.archetype $archetypeFile "../../platform/policies/assignments/sub/archetype-assignment.bicep"
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "Policy archetype applied successfully" -Level "SUCCESS"
                    } else {
                        Write-Log "Policy archetype assignment had issues (exit code: $LASTEXITCODE)" -Level "WARN"
                    }
                }
                catch {
                    Write-Log "Failed to apply policy archetype: $_" -Level "WARN"
                }
            } else {
                Write-Log "Policy archetype script not found: $archetypeScript" -Level "WARN"
            }
        } else {
            Write-Log "No archetype specified for subscription, skipping policy assignment" -Level "INFO"
        }
        
        # Apply RBAC role assignments
        # Note: deploy-role-assignments.ps1 reads from generated-role-assignments.json file
        # It doesn't take subscription ID as parameter, so RBAC needs to be configured separately
        # via the identity system's capability-based access model
        if ($subscription.ownerAadGroup) {
            Write-Log "RBAC role assignments are managed via platform/identity/ system" -Level "INFO"
            Write-Log "Owner group '$($subscription.ownerAadGroup)' is configured but assignments must be deployed separately" -Level "INFO"
            Write-Log "See: platform/identity/scripts/deploy-role-assignments.ps1" -Level "INFO"
            Write-Log "Note: This requires generating role assignments first via platform/identity/scripts/generate-capability-access.ps1" -Level "INFO"
        } else {
            Write-Log "No ownerAadGroup specified for subscription, skipping RBAC assignment" -Level "INFO"
        }
    }
} else {
    Write-Log "Skipping governance deployment (--SkipGovernance specified)" -Level "WARN"
}

# =============================================================================
# Summary
# =============================================================================

Write-Log "Subscription bootstrap completed successfully" -Level "SUCCESS"
Write-Log "Subscription: $($subscription.displayName)"
Write-Log "Azure Sub ID: $azSubscriptionId"
Write-Log "Logging RG: $loggingRgName"
Write-Log "Log Analytics: $laResourceId"
Write-Log ""
Write-Log "Next steps:"
Write-Log "1. Deploy networking (if needed): platform/connectivity/scripts/deploy-connectivity.ps1"
Write-Log "2. Deploy domain-specific resources (management, workloads, etc.)"
Write-Log "3. Verify governance policies are applied correctly"
