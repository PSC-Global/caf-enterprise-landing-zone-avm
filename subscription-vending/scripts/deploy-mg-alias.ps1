#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys subscription alias and moves it to target management group
    
.DESCRIPTION
    Orchestrates the deployment of a new Azure subscription using MCA billing alias
    and associates it with the specified management group. Includes idempotency checks
    and retry logic for eventual consistency.
    
.PARAMETER ConfigFile
    Path to subscriptions.json configuration file
    
.PARAMETER SubscriptionId
    The subscription ID (aliasName) from the config to deploy
    
.PARAMETER BillingScope
    Override billing scope from config (optional)
    
.EXAMPLE
    ./deploy-mg-alias.ps1 -SubscriptionId "platform-management" -WhatIf
    
.EXAMPLE
    ./deploy-mg-alias.ps1 -SubscriptionId "platform-connectivity" -BillingScope "/providers/Microsoft.Billing/..."
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "../config/subscriptions.json",
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$BillingScope
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Capture whether the built-in -WhatIf common parameter was supplied
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

function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 10,
        [string]$ErrorMessage = "Operation failed after retries"
    )
    
    $attempt = 0
    $lastError = $null
    
    while ($attempt -lt $MaxRetries) {
        try {
            $result = & $ScriptBlock
            return $result
        }
        catch {
            $lastError = $_
            $attempt++
            if ($attempt -lt $MaxRetries) {
                Write-Log "Attempt $attempt failed, retrying in $RetryDelaySeconds seconds... ($_)" -Level "WARN"
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    
    Write-Log "$ErrorMessage : $lastError" -Level "ERROR"
    throw $lastError
}

function Test-SubscriptionAlias {
    param([string]$AliasName)
    
    try {
        $alias = az rest --method GET `
            --uri "https://management.azure.com/providers/Microsoft.Subscription/aliases/$AliasName?api-version=2021-10-01" `
            --query "properties.subscriptionId" -o tsv 2>$null
        return ![string]::IsNullOrWhiteSpace($alias)
    }
    catch {
        return $false
    }
}

function Get-SubscriptionIdFromAlias {
    param([string]$AliasName)
    
    try {
        $subscriptionId = az rest --method GET `
            --uri "https://management.azure.com/providers/Microsoft.Subscription/aliases/$AliasName?api-version=2021-10-01" `
            --query "properties.subscriptionId" -o tsv 2>$null
        return $subscriptionId
    }
    catch {
        return $null
    }
}

function Get-SubscriptionManagementGroup {
    param([string]$SubscriptionId)
    
    try {
        $mg = az account management-group subscription show `
            --subscription $SubscriptionId `
            --query "id" -o tsv 2>$null
        
        if ($mg) {
            # Extract MG name from full path
            $mgName = $mg.Split('/')[-1]
            return $mgName
        }
    }
    catch {
        # Subscription might not be in any MG yet
    }
    
    return $null
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
$subscription = $config.subscriptions | Where-Object { $_.aliasName -eq $SubscriptionId -or $_.displayName -eq $SubscriptionId }

if (!$subscription) {
    Write-Log "Subscription '$SubscriptionId' not found in configuration (checked aliasName and displayName)" -Level "ERROR"
    exit 1
}

Write-Log "Found subscription: $($subscription.displayName)"
Write-Log "Target MG: $($subscription.targetMg)"
Write-Log "Primary region: $($subscription.primaryRegion)"

# =============================================================================
# Idempotency Check: Check if subscription already exists
# =============================================================================

Write-Log "Checking if subscription alias already exists..." -Level "INFO"

$existingSubscriptionId = $null
if (Test-SubscriptionAlias -AliasName $subscription.aliasName) {
    Write-Log "Subscription alias '$($subscription.aliasName)' already exists" -Level "WARN"
    $existingSubscriptionId = Get-SubscriptionIdFromAlias -AliasName $subscription.aliasName
    
    if ($existingSubscriptionId) {
        Write-Log "Existing subscription ID: $existingSubscriptionId" -Level "INFO"
        
        # Check current MG
        $currentMg = Get-SubscriptionManagementGroup -SubscriptionId $existingSubscriptionId
        if ($currentMg) {
            Write-Log "Subscription is currently in MG: $currentMg" -Level "INFO"
            
            if ($currentMg -eq $subscription.targetMg) {
                Write-Log "Subscription is already in the correct MG. Skipping deployment." -Level "SUCCESS"
                Write-Log "Subscription ID: $existingSubscriptionId" -Level "INFO"
                exit 0
            } else {
                Write-Log "Subscription is in different MG. Will move to target MG: $($subscription.targetMg)" -Level "WARN"
                $newSubscriptionId = $existingSubscriptionId
            }
        } else {
            Write-Log "Subscription is not in any MG. Will move to target MG: $($subscription.targetMg)" -Level "WARN"
            $newSubscriptionId = $existingSubscriptionId
        }
    }
}

# =============================================================================
# Prepare Deployment Parameters
# =============================================================================

$billingScope = if ($BillingScope) { $BillingScope } else { $subscription.billingScope }

if ([string]::IsNullOrWhiteSpace($billingScope) -or $billingScope -match '^<.*>$' -or $billingScope -notmatch '^/providers/Microsoft\.Billing/') {
    Write-Log "Billing scope not configured or invalid for subscription '$($subscription.aliasName)'" -Level "ERROR"
    Write-Log "Current value: '$billingScope'" -Level "ERROR"
    Write-Log "Please update the billingScope field in subscriptions.json with a valid MCA billing scope" -Level "ERROR"
    Write-Log "Format: /providers/Microsoft.Billing/billingAccounts/<id>/billingProfiles/<id>/invoiceSections/<id>" -Level "INFO"
    if ($config.subscriptions.Count -gt 0 -and $config.subscriptions[0].billingScope -match '^/providers/Microsoft\.Billing/') {
        Write-Log "Example from working subscription: $($config.subscriptions[0].billingScope)" -Level "INFO"
    }
    exit 1
}

$deploymentName = "sub-alias-$($subscription.aliasName)-$(Get-Date -Format 'yyMMddHHmmss')"
$targetMg = $subscription.targetMg

# Use primary region from config, fallback to australiaeast
$deploymentLocation = if ($subscription.primaryRegion) { $subscription.primaryRegion } else { "australiaeast" }

# Determine workload string - default to Production for prod/nonprod, DevTest for sandbox
# Derive from targetMg or role if needed
$workload = if ($subscription.role -eq "sandbox") { "DevTest" } else { "Production" }

# Build CLI parameters in name=value form (required by az deployment)
$aliasParams = @(
    "aliasName=$($subscription.aliasName)",
    "displayName=$($subscription.displayName)",
    "billingScope=$billingScope",
    "workload=$workload",
    "tags=$($subscription.tags | ConvertTo-Json -Compress)"
)

Write-Log "Deployment name: $deploymentName"
Write-Log "Alias name: $($subscription.aliasName)"
Write-Log "Deployment location: $deploymentLocation"

# =============================================================================
# Phase 1: Create Subscription Alias (if not exists)
# =============================================================================

if ($existingSubscriptionId) {
    Write-Log "Phase 1: Subscription already exists, skipping alias creation" -Level "SUCCESS"
    $newSubscriptionId = $existingSubscriptionId
} else {
    Write-Log "Phase 1: Creating subscription alias at tenant scope" -Level "SUCCESS"
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy create-alias.bicep at tenant scope" -Level "WARN"
        Write-Log "Parameters: $($aliasParams -join ' ; ')" -Level "WARN"
        $newSubscriptionId = "00000000-0000-0000-0000-000000000000"
    } else {
        try {
            $aliasDeployment = Invoke-WithRetry -ScriptBlock {
                az deployment tenant create `
                    --name $deploymentName `
                    --location $deploymentLocation `
                    --template-file "../mg-orchestration/create-alias.bicep" `
                    --parameters $aliasParams `
                    --output json | ConvertFrom-Json
            } -MaxRetries 3 -RetryDelaySeconds 15 -ErrorMessage "Failed to create subscription alias after retries"
            
            $newSubscriptionId = $aliasDeployment.properties.outputs.subscriptionId.value
            
            if ([string]::IsNullOrWhiteSpace($newSubscriptionId)) {
                Write-Log "Subscription alias created but subscription ID is empty. Waiting for provisioning..." -Level "WARN"
                
                # Wait for subscription to be provisioned
                $maxWait = 60
                $waited = 0
                while ($waited -lt $maxWait) {
                    Start-Sleep -Seconds 5
                    $waited += 5
                    $newSubscriptionId = Get-SubscriptionIdFromAlias -AliasName $subscription.aliasName
                    if ($newSubscriptionId) {
                        break
                    }
                    Write-Log "Waiting for subscription to be provisioned... ($waited/$maxWait seconds)" -Level "INFO"
                }
            }
            
            if ([string]::IsNullOrWhiteSpace($newSubscriptionId)) {
                Write-Log "Subscription ID not available after waiting. Please check subscription alias manually." -Level "ERROR"
                exit 1
            }
            
            Write-Log "Subscription created: $newSubscriptionId" -Level "SUCCESS"
        }
        catch {
            Write-Log "Failed to create subscription alias: $_" -Level "ERROR"
            exit 1
        }
    }
}

# =============================================================================
# Phase 2: Move Subscription to Management Group
# =============================================================================

Write-Log "Phase 2: Associating subscription with management group" -Level "SUCCESS"

# Check if already in correct MG
$currentMg = Get-SubscriptionManagementGroup -SubscriptionId $newSubscriptionId
if ($currentMg -eq $targetMg) {
    Write-Log "Subscription is already in target MG '$targetMg'. Skipping move operation." -Level "SUCCESS"
} else {
    $moveDeploymentName = "sub-move-$($subscription.aliasName)-$(Get-Date -Format 'yyMMddHHmmss')"
    
    $moveSubscriptionId = if ($IsWhatIf) { "00000000-0000-0000-0000-000000000000" } else { $newSubscriptionId }
    
    $moveParams = @(
        "subscriptionId=$moveSubscriptionId",
        "targetManagementGroupId=$targetMg"
    )
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy move-to-mg.bicep at tenant scope" -Level "WARN"
        Write-Log "Parameters: $($moveParams -join ' ; ')" -Level "WARN"
    } else {
        try {
            # Wait a bit for subscription to be fully ready before moving
            if (!$existingSubscriptionId) {
                Write-Log "Waiting for subscription to be ready before moving to MG..." -Level "INFO"
                Start-Sleep -Seconds 10
            }
            
            Invoke-WithRetry -ScriptBlock {
                az deployment tenant create `
                    --name $moveDeploymentName `
                    --location $deploymentLocation `
                    --template-file "../mg-orchestration/move-to-mg.bicep" `
                    --parameters $moveParams `
                    --output json | Out-Null
            } -MaxRetries 3 -RetryDelaySeconds 15 -ErrorMessage "Failed to move subscription to MG after retries"
            
            Write-Log "Subscription associated with MG: $targetMg" -Level "SUCCESS"
        }
        catch {
            Write-Log "Failed to move subscription: $_" -Level "ERROR"
            Write-Log "Subscription was created but not moved to MG. You may need to move it manually." -Level "WARN"
            exit 1
        }
    }
}

# =============================================================================
# Phase 3: Create DR Subscription (if enabled)
# =============================================================================

$drSubscriptionId = $null
if ($subscription.drSubscription -and $subscription.drSubscription.enabled -eq $true) {
    Write-Log "Phase 3: Creating DR subscription" -Level "SUCCESS"
    
    # Prepare DR subscription config
    $drAliasName = if ($subscription.drSubscription.aliasName) {
        $subscription.drSubscription.aliasName
    } else {
        "$($subscription.aliasName)-dr"
    }
    
    $drDisplayName = $drAliasName
    $drTargetMg = if ($subscription.drSubscription.targetMg) {
        $subscription.drSubscription.targetMg
    } else {
        $targetMg
    }
    
    $drRegion = $subscription.drSubscription.primaryRegion
    $drArchetype = if ($subscription.drSubscription.archetype) {
        $subscription.drSubscription.archetype
    } else {
        $subscription.archetype
    }
    
    $drOwnerGroup = if ($subscription.drSubscription.ownerAadGroup) {
        $subscription.drSubscription.ownerAadGroup
    } else {
        $subscription.ownerAadGroup
    }
    
    $drTags = if ($subscription.drSubscription.tags) {
        $subscription.drSubscription.tags
    } else {
        $subscription.tags
    }
    # Add DR tag
    $drTags = $drTags | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $drTags | Add-Member -NotePropertyName "drRegion" -NotePropertyValue "true" -Force
    $drTags | Add-Member -NotePropertyName "drPair" -NotePropertyValue $newSubscriptionId -Force
    
    Write-Log "DR Subscription Configuration:" -Level "INFO"
    Write-Log "  Alias Name: $drAliasName"
    Write-Log "  Target MG: $drTargetMg"
    Write-Log "  Region: $drRegion"
    Write-Log "  DR Mode: $($subscription.drSubscription.drMode)"
    
    # Check if DR subscription already exists
    if (Test-SubscriptionAlias -AliasName $drAliasName) {
        Write-Log "DR subscription alias '$drAliasName' already exists" -Level "WARN"
        $drSubscriptionId = Get-SubscriptionIdFromAlias -AliasName $drAliasName
        Write-Log "Existing DR subscription ID: $drSubscriptionId" -Level "INFO"
    } else {
        $drDeploymentName = "sub-alias-$drAliasName-$(Get-Date -Format 'yyMMddHHmmss')"
        
        $drAliasParams = @(
            "aliasName=$drAliasName",
            "displayName=$drDisplayName",
            "billingScope=$billingScope",
            "workload=Production",
            "tags=$($drTags | ConvertTo-Json -Compress)"
        )
        
        if ($IsWhatIf) {
            Write-Log "WhatIf: Would create DR subscription alias '$drAliasName'" -Level "WARN"
            $drSubscriptionId = "00000000-0000-0000-0000-000000000000"
        } else {
            try {
                $drAliasDeployment = Invoke-WithRetry -ScriptBlock {
                    az deployment tenant create `
                        --name $drDeploymentName `
                        --location $drRegion `
                        --template-file "../mg-orchestration/create-alias.bicep" `
                        --parameters $drAliasParams `
                        --output json | ConvertFrom-Json
                } -MaxRetries 3 -RetryDelaySeconds 15 -ErrorMessage "Failed to create DR subscription alias after retries"
                
                $drSubscriptionId = $drAliasDeployment.properties.outputs.subscriptionId.value
                
                if ([string]::IsNullOrWhiteSpace($drSubscriptionId)) {
                    $maxWait = 60
                    $waited = 0
                    while ($waited -lt $maxWait) {
                        Start-Sleep -Seconds 5
                        $waited += 5
                        $drSubscriptionId = Get-SubscriptionIdFromAlias -AliasName $drAliasName
                        if ($drSubscriptionId) { break }
                        Write-Log "Waiting for DR subscription to be provisioned... ($waited/$maxWait seconds)" -Level "INFO"
                    }
                }
                
                if ([string]::IsNullOrWhiteSpace($drSubscriptionId)) {
                    Write-Log "DR subscription ID not available after waiting." -Level "ERROR"
                } else {
                    Write-Log "DR subscription created: $drSubscriptionId" -Level "SUCCESS"
                }
            }
            catch {
                Write-Log "Failed to create DR subscription alias: $_" -Level "ERROR"
            }
        }
        
        # Move DR subscription to MG
        if ($drSubscriptionId -and !$IsWhatIf) {
            $drCurrentMg = Get-SubscriptionManagementGroup -SubscriptionId $drSubscriptionId
            if ($drCurrentMg -ne $drTargetMg) {
                $drMoveDeploymentName = "sub-move-$drAliasName-$(Get-Date -Format 'yyMMddHHmmss')"
                $drMoveParams = @(
                    "subscriptionId=$drSubscriptionId",
                    "targetManagementGroupId=$drTargetMg",
                    "tags=$($drTags | ConvertTo-Json -Compress)"
                )
                
                try {
                    Start-Sleep -Seconds 10
                    Invoke-WithRetry -ScriptBlock {
                        az deployment tenant create `
                            --name $drMoveDeploymentName `
                            --location $drRegion `
                            --template-file "../mg-orchestration/move-to-mg.bicep" `
                            --parameters $drMoveParams `
                            --output json | Out-Null
                    } -MaxRetries 3 -RetryDelaySeconds 15 -ErrorMessage "Failed to move DR subscription to MG"
                    
                    Write-Log "DR subscription associated with MG: $drTargetMg" -Level "SUCCESS"
                }
                catch {
                    Write-Log "Failed to move DR subscription: $_" -Level "ERROR"
                }
            }
        }
    }
}

# =============================================================================
# Summary
# =============================================================================

Write-Log "Subscription deployment completed successfully" -Level "SUCCESS"

if ($IsWhatIf) {
    Write-Log "Subscription ID: <would be returned from alias deployment>" -Level "INFO"
    if ($subscription.drSubscription -and $subscription.drSubscription.enabled) {
        Write-Log "DR Subscription ID: <would be returned from DR alias deployment>" -Level "INFO"
    }
} else {
    Write-Log "Subscription ID: $newSubscriptionId" -Level "INFO"
    if ($drSubscriptionId) {
        Write-Log "DR Subscription ID: $drSubscriptionId" -Level "INFO"
    }
}

Write-Log "Display Name: $($subscription.displayName)"
Write-Log "Management Group: $targetMg"
Write-Log ""
Write-Log "Next steps:"
Write-Log "1. Run deploy-subscription.ps1 to bootstrap the subscription"
if ($drSubscriptionId) {
    Write-Log "2. Run deploy-subscription.ps1 with DR subscription ID to bootstrap DR subscription"
}
Write-Log "$(if ($drSubscriptionId) { '3' } else { '2' }). Assign policy archetype using policies/scripts/assign-sub-archetype.sh"
Write-Log "$(if ($drSubscriptionId) { '4' } else { '3' }). Configure RBAC using platform/identity/scripts/deploy-role-assignments.ps1"
