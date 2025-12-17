<#
.SYNOPSIS
    Orchestrates the complete Azure Policy deployment and validation pipeline.

.DESCRIPTION
    This master script orchestrates the end-to-end policy governance pipeline:
    1. Validates prerequisites and environment
    2. Deploys policy assignments across all scopes
    3. Validates compliance and generates reports
    
    This is the primary entry point for policy governance automation.

.PARAMETER OrgId
    The organization ID prefix for management group names. Default: rai

.PARAMETER Location
    The Azure region for policy assignment metadata. Default: australiaeast

.PARAMETER SkipDeployment
    Skip policy deployment (validation only)

.PARAMETER SkipValidation
    Skip compliance validation (deployment only)

.EXAMPLE
    .\invoke-policy-pipeline.ps1
    Runs complete pipeline: deployment + validation

.EXAMPLE
    .\invoke-policy-pipeline.ps1 -SkipDeployment
    Runs validation only (assumes policies already deployed)

.NOTES
    Author: CAF Enterprise Landing Zone Team
    Prerequisites:
    - Azure CLI installed and authenticated
    - Owner or Policy Contributor role at tenant root
    - Management groups created via platform/management/mg-rai.bicep
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OrgId = 'rai',

    [Parameter(Mandatory = $false)]
    [string]$Location = 'australiaeast',

    [Parameter(Mandatory = $false)]
    [switch]$SkipDeployment,

    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation
)

# ============================================================================
# Script Configuration
# ============================================================================

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Get script root directory
$ScriptRoot = $PSScriptRoot

Write-Information ""
Write-Information "╔════════════════════════════════════════════════════════════════════════╗"
Write-Information "║        Azure Policy Governance Pipeline - CAF Landing Zones           ║"
Write-Information "╚════════════════════════════════════════════════════════════════════════╝"
Write-Information ""

$startTime = Get-Date

# ============================================================================
# Phase 1: Policy Deployment
# ============================================================================

if (-not $SkipDeployment) {
    Write-Information "═══════════════════════════════════════════════════════════════════════"
    Write-Information "Phase 1: Deploying Azure Security Benchmark Policy Assignments"
    Write-Information "═══════════════════════════════════════════════════════════════════════"
    Write-Information ""

    $deployScript = Join-Path $ScriptRoot 'deploy-policies.ps1'
    
    if (-not (Test-Path $deployScript)) {
        throw "Deployment script not found: $deployScript"
    }

    try {
        & $deployScript -OrgId $OrgId -Location $Location
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Policy deployment completed with warnings or errors. Check logs for details."
        }
        else {
            Write-Information ""
            Write-Information "✓ Policy deployment completed successfully"
        }
    }
    catch {
        Write-Error "Policy deployment failed: $($_.Exception.Message)"
        exit 1
    }

    # Wait for policy assignments to propagate
    Write-Information ""
    Write-Information "⏳ Waiting 60 seconds for policy assignments to propagate..."
    Start-Sleep -Seconds 60
}
else {
    Write-Information "⊗ Skipping policy deployment (SkipDeployment flag set)"
}

# ============================================================================
# Phase 2: Compliance Validation
# ============================================================================

if (-not $SkipValidation) {
    Write-Information ""
    Write-Information "═══════════════════════════════════════════════════════════════════════"
    Write-Information "Phase 2: Validating Policy Compliance"
    Write-Information "═══════════════════════════════════════════════════════════════════════"
    Write-Information ""

    $validationScript = Join-Path $ScriptRoot 'validate-policy-compliance.ps1'
    
    if (-not (Test-Path $validationScript)) {
        throw "Validation script not found: $validationScript"
    }

    try {
        & $validationScript -OrgId $OrgId -OutputFormat Both
        
        Write-Information ""
        Write-Information "✓ Compliance validation completed successfully"
    }
    catch {
        Write-Error "Compliance validation failed: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Information "⊗ Skipping compliance validation (SkipValidation flag set)"
}

# ============================================================================
# Pipeline Summary
# ============================================================================

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Information ""
Write-Information "╔════════════════════════════════════════════════════════════════════════╗"
Write-Information "║                      Pipeline Execution Summary                        ║"
Write-Information "╚════════════════════════════════════════════════════════════════════════╝"
Write-Information ""
Write-Information "Status: ✓ Pipeline completed successfully"
Write-Information "Duration: $($duration.TotalMinutes.ToString('F2')) minutes"
Write-Information "Organization: $OrgId"
Write-Information "Location: $Location"
Write-Information ""
Write-Information "─────────────────────────────────────────────────────────────────────────"
Write-Information "Next Steps:"
Write-Information "─────────────────────────────────────────────────────────────────────────"
Write-Information "1. Review compliance reports in: platform/policies/generated/"
Write-Information "2. Open HTML report in browser for detailed analysis"
Write-Information "3. Review ASB control mappings: platform/policies/config/asb-mapping/"
Write-Information "4. Plan remediation for non-compliant resources"
Write-Information "5. Update enforcementMode in parameter files for phased enforcement"
Write-Information "6. Schedule regular compliance validation (daily/weekly)"
Write-Information ""
Write-Information "For assistance, refer to CAF Landing Zone documentation or contact"
Write-Information "the platform engineering team."
Write-Information ""

exit 0
