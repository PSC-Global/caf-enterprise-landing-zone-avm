#Requires -Version 7.0
<#
.SYNOPSIS
    Orchestrates complete production deployment of CAF Enterprise Landing Zone platform

.DESCRIPTION
    This script orchestrates the deployment of all platform phases in the correct order:
    1. Phase 0: Guardrails & Contracts (verification only)
    2. Phase 1: Central Logging Backbone
    3. Phase 2: IP Governance & Subnet Standards (verification only)
    4. Phase 3: vWAN Secure Hub
    5. Phase 9: Policy Enforcement
    6. Phase 4: Spoke VNets (optional, can deploy multiple)
    7. Phase 5: Private DNS & Private Endpoints (optional, per VNet)
    8. Phase 6: Ingress Architecture (optional)
    9. Phase 7: Non-HTTP Ingress DNAT (optional, if configured)

.PARAMETER Phase
    Specific phase to deploy. If not specified, deploys all phases sequentially.
    Valid values: 0, 1, 2, 3, 4, 5, 6, 7, 9

.PARAMETER SkipValidation
    Skip post-deployment validation steps

.PARAMETER SpokeSubscriptions
    Array of spoke subscription aliases to deploy in Phase 4 (e.g., @("rai-lending-core-prod-01"))

.PARAMETER IngressSubscription
    Subscription alias for ingress deployment (Phase 6)

.PARAMETER WhatIf
    Shows what would be deployed without actually deploying

.EXAMPLE
    ./deploy-prod.ps1
    Deploys all phases sequentially

.EXAMPLE
    ./deploy-prod.ps1 -Phase 3
    Deploys only Phase 3 (vWAN Secure Hub)

.EXAMPLE
    ./deploy-prod.ps1 -SpokeSubscriptions @("rai-lending-core-prod-01", "rai-fraud-engine-prod-01")
    Deploys all phases, then deploys multiple spoke VNets in Phase 4

.EXAMPLE
    ./deploy-prod.ps1 -Phase 9 -WhatIf
    Shows what would be deployed for Phase 9 (Policy Enforcement) without deploying
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet(0, 1, 2, 3, 4, 5, 6, 7, 9, "all")]
    [object]$Phase = "all",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory = $false)]
    [string[]]$SpokeSubscriptions = @(),
    
    [Parameter(Mandatory = $false)]
    [string]$IngressSubscription = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Capture WhatIf mode
$IsWhatIf = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf')

# Get script root
$ScriptRoot = $PSScriptRoot
$RepoRoot = Split-Path -Parent $ScriptRoot

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
        "PHASE" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-PhaseHeader {
    param([string]$PhaseName, [string]$PhaseNumber)
    Write-Log "" -Level "INFO"
    Write-Log "============================================================================" -Level "PHASE"
    Write-Log "PHASE $PhaseNumber: $PhaseName" -Level "PHASE"
    Write-Log "============================================================================" -Level "PHASE"
}

function Invoke-PhaseDeployment {
    param(
        [string]$PhaseNumber,
        [string]$PhaseName,
        [scriptblock]$DeploymentScript,
        [scriptblock]$ValidationScript = $null
    )
    
    Write-PhaseHeader -PhaseName $PhaseName -PhaseNumber $PhaseNumber
    
    try {
        if ($IsWhatIf) {
            Write-Log "WhatIf: Would deploy $PhaseName" -Level "WARN"
            return $true
        }
        
        Write-Log "Starting deployment: $PhaseName" -Level "INFO"
        & $DeploymentScript
        
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Deployment script exited with code $LASTEXITCODE"
        }
        
        Write-Log "Deployment completed: $PhaseName" -Level "SUCCESS"
        
        if ($ValidationScript -and !$SkipValidation) {
            Write-Log "Running validation..." -Level "INFO"
            & $ValidationScript
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to deploy $PhaseName : $_" -Level "ERROR"
        return $false
    }
}

# =============================================================================
# Deployment Functions (per Phase)
# =============================================================================

function Deploy-Phase0 {
    Write-Log "Phase 0: Guardrails & Contracts (Verification Only)" -Level "INFO"
    
    $contractFile = Join-Path $RepoRoot "platform/shared/contract.bicep"
    $namingFile = Join-Path $RepoRoot "platform/shared/naming.bicep"
    
    if (!(Test-Path $contractFile)) {
        throw "Contract file not found: $contractFile"
    }
    if (!(Test-Path $namingFile)) {
        throw "Naming file not found: $namingFile"
    }
    
    Write-Log "Phase 0: Contracts verified" -Level "SUCCESS"
    return $true
}

function Deploy-Phase1 {
    $scriptPath = Join-Path $RepoRoot "platform/logging/scripts/deploy-logging.ps1"
    
    if (!(Test-Path $scriptPath)) {
        throw "Logging deployment script not found: $scriptPath"
    }
    
    Push-Location (Split-Path $scriptPath)
    
    try {
        $params = @{}
        if ($IsWhatIf) { $params['WhatIf'] = $true }
        
        & $scriptPath @params
    }
    finally {
        Pop-Location
    }
}

function Deploy-Phase2 {
    Write-Log "Phase 2: IP Governance & Subnet Standards (Verification Only)" -Level "INFO"
    
    $ipamFile = Join-Path $RepoRoot "platform/connectivity/config/ipam.json"
    $blueprintsFile = Join-Path $RepoRoot "platform/connectivity/config/subnet-blueprints.json"
    
    if (!(Test-Path $ipamFile)) {
        throw "IPAM config not found: $ipamFile"
    }
    if (!(Test-Path $blueprintsFile)) {
        throw "Subnet blueprints not found: $blueprintsFile"
    }
    
    $ipamConfig = Get-Content $ipamFile -Raw | ConvertFrom-Json
    $blueprints = Get-Content $blueprintsFile -Raw | ConvertFrom-Json
    
    Write-Log "IPAM pools configured: $($ipamConfig.ipamPools.Count)" -Level "INFO"
    Write-Log "Subnet profiles available: $($blueprints.profiles.PSObject.Properties.Count)" -Level "INFO"
    
    Write-Log "Phase 2: Configuration verified" -Level "SUCCESS"
    return $true
}

function Deploy-Phase3 {
    $scriptPath = Join-Path $RepoRoot "platform/connectivity/scripts/deploy-connectivity.ps1"
    
    if (!(Test-Path $scriptPath)) {
        throw "Connectivity deployment script not found: $scriptPath"
    }
    
    Push-Location (Split-Path $scriptPath)
    
    try {
        $params = @{
            SubscriptionId = "rai-platform-connectivity-prod-01"
        }
        if ($IsWhatIf) { $params['WhatIf'] = $true }
        
        & $scriptPath @params
    }
    finally {
        Pop-Location
    }
}

function Deploy-Phase9 {
    $scriptPath = Join-Path $RepoRoot "platform/policies/scripts/deploy-policies.ps1"
    
    if (!(Test-Path $scriptPath)) {
        throw "Policies deployment script not found: $scriptPath"
    }
    
    Push-Location (Split-Path $scriptPath)
    
    try {
        $params = @{}
        if ($IsWhatIf) { $params['WhatIf'] = $true }
        
        & $scriptPath @params
    }
    finally {
        Pop-Location
    }
}

function Deploy-Phase4 {
    param([string[]]$SubscriptionAliases)
    
    if ($SubscriptionAliases.Count -eq 0) {
        Write-Log "No spoke subscriptions specified. Skipping Phase 4." -Level "WARN"
        return $true
    }
    
    $scriptPath = Join-Path $RepoRoot "platform/connectivity/scripts/deploy-connectivity.ps1"
    
    if (!(Test-Path $scriptPath)) {
        throw "Connectivity deployment script not found: $scriptPath"
    }
    
    Push-Location (Split-Path $scriptPath)
    
    try {
        foreach ($subscriptionAlias in $SubscriptionAliases) {
            Write-Log "Deploying spoke VNet for: $subscriptionAlias" -Level "INFO"
            
            $params = @{
                SubscriptionId = $subscriptionAlias
            }
            if ($IsWhatIf) { $params['WhatIf'] = $true }
            
            & $scriptPath @params
            
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                Write-Log "Warning: Deployment failed for $subscriptionAlias" -Level "WARN"
            }
        }
    }
    finally {
        Pop-Location
    }
}

function Deploy-Phase6 {
    param([string]$SubscriptionAlias)
    
    if ([string]::IsNullOrWhiteSpace($SubscriptionAlias)) {
        Write-Log "No ingress subscription specified. Skipping Phase 6." -Level "WARN"
        return $true
    }
    
    $scriptPath = Join-Path $RepoRoot "platform/connectivity/scripts/deploy-connectivity.ps1"
    
    if (!(Test-Path $scriptPath)) {
        throw "Connectivity deployment script not found: $scriptPath"
    }
    
    Push-Location (Split-Path $scriptPath)
    
    try {
        $params = @{
            SubscriptionId = $SubscriptionAlias
        }
        if ($IsWhatIf) { $params['WhatIf'] = $true }
        
        & $scriptPath @params
    }
    finally {
        Pop-Location
    }
}

# =============================================================================
# Main Deployment Orchestration
# =============================================================================

Write-Log "========================================================================" -Level "PHASE"
Write-Log "CAF Enterprise Landing Zone - Production Deployment" -Level "PHASE"
Write-Log "========================================================================" -Level "PHASE"
Write-Log ""

if ($IsWhatIf) {
    Write-Log "RUNNING IN WHATIF MODE - NO CHANGES WILL BE MADE" -Level "WARN"
    Write-Log ""
}

# Determine which phases to deploy
$phasesToDeploy = @()
if ($Phase -eq "all") {
    $phasesToDeploy = @(0, 1, 2, 3, 9, 4, 6)
} else {
    $phasesToDeploy = @([int]$Phase)
}

$deploymentResults = @{}

foreach ($phaseNum in $phasesToDeploy) {
    $success = $false
    
    switch ($phaseNum) {
        0 {
            $success = Invoke-PhaseDeployment `
                -PhaseNumber "0" `
                -PhaseName "Guardrails & Contracts" `
                -DeploymentScript ${function:Deploy-Phase0}
        }
        1 {
            $success = Invoke-PhaseDeployment `
                -PhaseNumber "1" `
                -PhaseName "Central Logging Backbone" `
                -DeploymentScript ${function:Deploy-Phase1}
        }
        2 {
            $success = Invoke-PhaseDeployment `
                -PhaseNumber "2" `
                -PhaseName "IP Governance & Subnet Standards" `
                -DeploymentScript ${function:Deploy-Phase2}
        }
        3 {
            $success = Invoke-PhaseDeployment `
                -PhaseNumber "3" `
                -PhaseName "vWAN Secure Hub" `
                -DeploymentScript ${function:Deploy-Phase3}
        }
        9 {
            $success = Invoke-PhaseDeployment `
                -PhaseNumber "9" `
                -PhaseName "Policy Enforcement" `
                -DeploymentScript ${function:Deploy-Phase9}
        }
        4 {
            $success = Invoke-PhaseDeployment `
                -PhaseNumber "4" `
                -PhaseName "Spoke VNets (Landing Zones)" `
                -DeploymentScript { Deploy-Phase4 -SubscriptionAliases $SpokeSubscriptions }
        }
        6 {
            $success = Invoke-PhaseDeployment `
                -PhaseNumber "6" `
                -PhaseName "Ingress Architecture (WAF)" `
                -DeploymentScript { Deploy-Phase6 -SubscriptionAlias $IngressSubscription }
        }
        default {
            Write-Log "Phase $phaseNum not implemented or invalid" -Level "WARN"
            $success = $false
        }
    }
    
    $deploymentResults[$phaseNum] = $success
    
    if (!$success -and !$IsWhatIf) {
        Write-Log "Deployment stopped due to failure in Phase $phaseNum" -Level "ERROR"
        break
    }
    
    Write-Log ""
}

# =============================================================================
# Deployment Summary
# =============================================================================

Write-Log "========================================================================" -Level "PHASE"
Write-Log "DEPLOYMENT SUMMARY" -Level "PHASE"
Write-Log "========================================================================" -Level "PHASE"
Write-Log ""

foreach ($phaseNum in $phasesToDeploy) {
    $status = if ($deploymentResults[$phaseNum]) { "SUCCESS" } else { "FAILED" }
    $color = if ($deploymentResults[$phaseNum]) { "Green" } else { "Red" }
    Write-Host "  Phase $phaseNum : $status" -ForegroundColor $color
}

$allSuccessful = ($deploymentResults.Values | Where-Object { $_ -eq $false }).Count -eq 0

Write-Log ""
if ($allSuccessful -or $IsWhatIf) {
    Write-Log "Deployment completed successfully!" -Level "SUCCESS"
    Write-Log ""
    Write-Log "Next steps:" -Level "INFO"
    Write-Log "1. Review validation checklist in docs/PROD-DEPLOYMENT-RUNBOOK.md" -Level "INFO"
    Write-Log "2. Verify resources in Azure Portal" -Level "INFO"
    Write-Log "3. Check diagnostic logs are flowing to LAW" -Level "INFO"
    Write-Log "4. Test connectivity from spoke VNets" -Level "INFO"
} else {
    Write-Log "Deployment completed with failures. Review errors above." -Level "ERROR"
    exit 1
}
