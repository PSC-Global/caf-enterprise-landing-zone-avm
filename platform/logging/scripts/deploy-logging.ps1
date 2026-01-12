#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys central logging backbone infrastructure for the platform

.DESCRIPTION
    Deploys the central Log Analytics Workspace and Action Groups for platform telemetry.
    This is Phase 1 of the platform deployment and must be completed before other phases.

    Creates:
    - Resource Group for logging resources
    - Log Analytics Workspace (central telemetry sink)
    - Action Groups for alerting

.PARAMETER SubscriptionId
    Azure subscription ID or aliasName to deploy logging to
    Default: rai-platform-logging-prod-01

.PARAMETER ConfigFile
    Path to logging configuration JSON file
    Default: ../config/logging.prod.json

.PARAMETER Location
    Azure region for deployment (overrides config file)
    Default: australiaeast

.PARAMETER WhatIf
    Shows what would be deployed without actually deploying

.EXAMPLE
    ./deploy-logging.ps1
    Deploys central logging to rai-platform-logging-prod-01 subscription

.EXAMPLE
    ./deploy-logging.ps1 -SubscriptionId "rai-platform-logging-prod-01" -WhatIf
    Shows what would be deployed without actually deploying

.EXAMPLE
    ./deploy-logging.ps1 -SubscriptionId "xxx-xxx-xxx" -ConfigFile "../config/logging.prod.json"
    Deploys with custom subscription ID and config file
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = "rai-platform-logging-prod-01",
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "../config/logging.prod.json",
    
    [Parameter(Mandatory = $false)]
    [string]$Location,
    
    [Parameter(Mandatory = $false)]
    [string]$BicepFile = "../bicep/logging-prod.bicep"
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

function Restore-BicepModules {
    param([string]$BicepFile)
    
    Write-Log "Restoring Bicep modules for $BicepFile" -Level "INFO"
    az bicep build --file $BicepFile --outfile /dev/null 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Warning: Bicep module restore had issues, but continuing..." -Level "WARN"
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

# Override location if provided
if ($Location) {
    $config.parameters.location.value = $Location
    Write-Log "Location overridden to: $Location" -Level "INFO"
}

# =============================================================================
# Resolve Azure Subscription ID
# =============================================================================

Write-Log "Resolving Azure subscription for: $SubscriptionId"

# Try to resolve as subscription alias first
$azSubscriptionId = (az account subscription alias show --name $SubscriptionId --query "properties.subscriptionId" -o tsv 2>$null)

if ([string]::IsNullOrWhiteSpace($azSubscriptionId)) {
    # If not found as alias, try as direct subscription ID
    $azSubscriptionId = Normalize-SubscriptionId -SubscriptionId $SubscriptionId
    
    if ([string]::IsNullOrWhiteSpace($azSubscriptionId)) {
        Write-Log "Could not find Azure subscription for '$SubscriptionId'." -Level "ERROR"
        Write-Log "Please ensure the subscription exists or provide a valid subscription ID/alias." -Level "ERROR"
        exit 1
    }
} else {
    $azSubscriptionId = Normalize-SubscriptionId -SubscriptionId $azSubscriptionId
}

Write-Log "Using Azure Subscription ID: $azSubscriptionId" -Level "INFO"

# Set subscription context
az account set --subscription $azSubscriptionId | Out-Null

# =============================================================================
# Validate Bicep Template
# =============================================================================

if (!(Test-Path $BicepFile)) {
    Write-Log "Bicep template not found: $BicepFile" -Level "ERROR"
    exit 1
}

Write-Log "Validating Bicep template: $BicepFile" -Level "INFO"
Restore-BicepModules -BicepFile $BicepFile

# =============================================================================
# Deploy Central Logging Infrastructure
# =============================================================================

Write-Log "Phase 1: Deploying central logging backbone" -Level "SUCCESS"
Write-Log "Subscription: $SubscriptionId"
Write-Log "Azure Sub ID: $azSubscriptionId"
Write-Log "Location: $($config.parameters.location.value)"
Write-Log "Workspace Name: $($config.parameters.logAnalyticsWorkspaceName.value)"

$deploymentName = "logging-prod-$(Get-Date -Format 'yyyyMMddHHmmss')"

if ($IsWhatIf) {
    Write-Log "WhatIf: Would deploy central logging infrastructure" -Level "WARN"
    Write-Log "Deployment name: $deploymentName" -Level "WARN"
    Write-Log "Parameters file: $ConfigFile" -Level "WARN"
} else {
    try {
        Write-Log "Deploying central logging infrastructure..." -Level "INFO"
        
        # Step 1: Deploy resource group (subscription scope)
        Write-Log "Step 1: Creating resource group..." -Level "INFO"
        az deployment sub create `
            --subscription $azSubscriptionId `
            --location $($config.parameters.location.value) `
            --name $deploymentName `
            --template-file $BicepFile `
            --parameters $ConfigFile `
            --output json | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Resource group deployment failed with exit code $LASTEXITCODE"
        }
        
        # Get resource group name from deployment output
        $rgOutputs = az deployment sub show `
            --subscription $azSubscriptionId `
            --name $deploymentName `
            --query "properties.outputs" -o json | ConvertFrom-Json
        
        $rgName = $rgOutputs.resourceGroupName.value
        Write-Log "Resource group created: $rgName" -Level "SUCCESS"
        
        # Step 2: Deploy Log Analytics Workspace (resource group scope)
        Write-Log "Step 2: Deploying Log Analytics Workspace..." -Level "INFO"
        $lawDeploymentName = "law-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        $lawParams = @(
            "environment=prod",
            "location=$($config.parameters.location.value)",
            "tags=$($config.parameters.tags.value | ConvertTo-Json -Compress)",
            "workspaceName=$($config.parameters.logAnalyticsWorkspaceName.value)",
            "retentionInDays=$($config.parameters.retentionInDays.value)",
            "skuName=$($config.parameters.skuName.value)",
            "dailyQuotaGb=$($config.parameters.dailyQuotaGb.value)"
        )
        
        az deployment group create `
            --subscription $azSubscriptionId `
            --resource-group $rgName `
            --name $lawDeploymentName `
            --template-file "../bicep/log-analytics-workspace.bicep" `
            --parameters $lawParams `
            --output json | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Log Analytics Workspace deployment failed with exit code $LASTEXITCODE"
        }
        
        # Get LAW outputs
        $lawOutputs = az deployment group show `
            --subscription $azSubscriptionId `
            --resource-group $rgName `
            --name $lawDeploymentName `
            --query "properties.outputs" -o json | ConvertFrom-Json
        
        Write-Log "Log Analytics Workspace deployed successfully" -Level "SUCCESS"
        
        # Step 3: Deploy Action Groups (if configured, resource group scope)
        $actionGroupNames = @()
        $actionGroupResourceIds = @()
        
        if ($config.parameters.actionGroupConfigs.value.Count -gt 0) {
            Write-Log "Step 3: Deploying Action Groups..." -Level "INFO"
            $agDeploymentName = "ag-$(Get-Date -Format 'yyyyMMddHHmmss')"
            
            $agParams = @(
                "environment=prod",
                "location=$($config.parameters.location.value)",
                "tags=$($config.parameters.tags.value | ConvertTo-Json -Compress)",
                "actionGroupConfigs=$($config.parameters.actionGroupConfigs.value | ConvertTo-Json -Compress -Depth 10)"
            )
            
            az deployment group create `
                --subscription $azSubscriptionId `
                --resource-group $rgName `
                --name $agDeploymentName `
                --template-file "../bicep/action-groups.bicep" `
                --parameters $agParams `
                --output json | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Action Groups deployment failed, but continuing..." -Level "WARN"
            } else {
                $agOutputs = az deployment group show `
                    --subscription $azSubscriptionId `
                    --resource-group $rgName `
                    --name $agDeploymentName `
                    --query "properties.outputs" -o json | ConvertFrom-Json
                
                $actionGroupNames = $agOutputs.actionGroupNames.value
                $actionGroupResourceIds = $agOutputs.actionGroupResourceIds.value
                Write-Log "Action Groups deployed successfully" -Level "SUCCESS"
            }
        }
        
        Write-Log "Central logging infrastructure deployed successfully" -Level "SUCCESS"
        
        # Display final outputs
        Write-Log "" -Level "INFO"
        Write-Log "Deployment Outputs:" -Level "SUCCESS"
        Write-Log "  Log Analytics Workspace Resource ID: $($lawOutputs.logAnalyticsWorkspaceResourceId.value)" -Level "INFO"
        Write-Log "  Log Analytics Workspace Name: $($lawOutputs.logAnalyticsWorkspaceName.value)" -Level "INFO"
        Write-Log "  Resource Group Name: $rgName" -Level "INFO"
        
        if ($actionGroupNames.Count -gt 0) {
            Write-Log "  Action Groups Deployed: $($actionGroupNames.Count)" -Level "INFO"
            foreach ($agName in $actionGroupNames) {
                Write-Log "    - $agName" -Level "INFO"
            }
        }
        
    }
    catch {
        Write-Log "Failed to deploy central logging infrastructure: $_" -Level "ERROR"
        exit 1
    }
}

# =============================================================================
# Summary
# =============================================================================

Write-Log "" -Level "INFO"
Write-Log "Central logging deployment completed" -Level "SUCCESS"
Write-Log "" -Level "INFO"
Write-Log "Next steps:" -Level "INFO"
Write-Log "1. Verify Log Analytics Workspace in Azure Portal" -Level "INFO"
Write-Log "2. Configure diagnostic settings for platform resources" -Level "INFO"
Write-Log "3. Set up alert rules using the deployed action groups" -Level "INFO"
Write-Log "4. Use logAnalyticsWorkspaceResourceId output in downstream phases" -Level "INFO"
