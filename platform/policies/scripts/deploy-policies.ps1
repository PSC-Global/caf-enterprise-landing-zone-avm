<#
.SYNOPSIS
    Deploys Azure Security Benchmark policy assignments across the CAF management group hierarchy.

.DESCRIPTION
    This script orchestrates the deployment of Azure Security Benchmark v3 policy assignments
    at tenant root and across all platform and landing zone management groups.
    
    Deployment sequence:
    1. Tenant root (applies to all subscriptions and management groups)
    2. Platform management groups (identity, connectivity, management)
    3. Landing zone management groups (corp, online)
    
    All assignments are deployed in audit-only mode (DoNotEnforce) for initial compliance assessment.
    Enforcement mode can be transitioned to 'Default' in a phased approach.

.PARAMETER Location
    The Azure region for policy assignment metadata. Default: australiaeast

.PARAMETER OrgId
    The organization ID prefix for management group names. Default: rai

.PARAMETER SkipTenantScope
    Skip tenant-scoped deployment (useful for testing MG-scoped assignments only)

.PARAMETER TargetMGs
    Array of specific management group names to deploy. If not specified, deploys to all.
    Valid values: platform-identity, platform-connectivity, platform-management, corp, online

.EXAMPLE
    .\deploy-policies.ps1
    Deploys all ASB policy assignments across tenant and management groups

.EXAMPLE
    .\deploy-policies.ps1 -SkipTenantScope -TargetMGs @('platform-identity', 'corp')
    Deploys only to Platform Identity and Corp management groups

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
    [string]$Location = 'australiaeast',

    [Parameter(Mandatory = $false)]
    [string]$OrgId = 'rai',

    [Parameter(Mandatory = $false)]
    [switch]$SkipTenantScope,

    [Parameter(Mandatory = $false)]
    [ValidateSet('platform-identity', 'platform-connectivity', 'platform-management', 'corp', 'online')]
    [string[]]$TargetMGs
)

# ============================================================================
# Script Configuration
# ============================================================================

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Get script root directory
$ScriptRoot = $PSScriptRoot
$PoliciesRoot = Split-Path -Parent $ScriptRoot

# Define paths
$BicepRoot = Join-Path $PoliciesRoot 'bicep'
$ParamsRoot = Join-Path $PoliciesRoot 'config/parameters'
$GeneratedRoot = Join-Path $PoliciesRoot 'generated'

# Ensure generated folder exists
if (-not (Test-Path $GeneratedRoot)) {
    New-Item -Path $GeneratedRoot -ItemType Directory -Force | Out-Null
}

# Deployment tracking
$DeploymentTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$DeploymentLog = Join-Path $GeneratedRoot "deployment-log-$DeploymentTimestamp.json"
$DeploymentResults = @()

# ============================================================================
# Helper Functions
# ============================================================================

function Write-DeploymentHeader {
    param([string]$Message)
    Write-Information ""
    Write-Information "============================================================================"
    Write-Information $Message
    Write-Information "============================================================================"
}

function Write-DeploymentStep {
    param([string]$Message)
    Write-Information ""
    Write-Information "→ $Message"
}

function Invoke-PolicyDeployment {
    param(
        [Parameter(Mandatory)]
        [string]$Scope,
        
        [Parameter(Mandatory)]
        [string]$ScopeName,
        
        [Parameter(Mandatory)]
        [string]$TemplateFile,
        
        [Parameter(Mandatory)]
        [string]$ParameterFile,
        
        [Parameter(Mandatory)]
        [string]$DeploymentName
    )

    $startTime = Get-Date
    
    try {
        Write-DeploymentStep "Deploying: $DeploymentName"
        Write-Information "  Scope: $Scope"
        Write-Information "  Template: $(Split-Path -Leaf $TemplateFile)"
        Write-Information "  Parameters: $(Split-Path -Leaf $ParameterFile)"

        # Build deployment command based on scope
        switch ($Scope) {
            'tenant' {
                $output = az deployment tenant create `
                    --name $DeploymentName `
                    --location $Location `
                    --template-file $TemplateFile `
                    --parameters "@$ParameterFile" `
                    --output json 2>&1
            }
            default {
                # Management group scope
                $mgId = "$OrgId-$Scope"
                $output = az deployment mg create `
                    --name $DeploymentName `
                    --management-group-id $mgId `
                    --location $Location `
                    --template-file $TemplateFile `
                    --parameters "@$ParameterFile" `
                    --output json 2>&1
            }
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Deployment failed with exit code $LASTEXITCODE`: $output"
        }

        $deploymentOutput = $output | ConvertFrom-Json
        $duration = (Get-Date) - $startTime

        Write-Information "  ✓ Deployment successful (Duration: $($duration.TotalSeconds)s)"
        
        # Track deployment result
        $result = @{
            Scope = $ScopeName
            DeploymentName = $DeploymentName
            Status = 'Success'
            Duration = $duration.TotalSeconds
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            AssignmentId = $deploymentOutput.properties.outputs.assignmentId.value
            AssignmentName = $deploymentOutput.properties.outputs.assignmentName.value
            EnforcementMode = $deploymentOutput.properties.outputs.enforcementMode.value
        }
        
        return $result
    }
    catch {
        $duration = (Get-Date) - $startTime
        Write-Error "  ✗ Deployment failed: $($_.Exception.Message)"
        
        # Track deployment failure
        $result = @{
            Scope = $ScopeName
            DeploymentName = $DeploymentName
            Status = 'Failed'
            Duration = $duration.TotalSeconds
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Error = $_.Exception.Message
        }
        
        return $result
    }
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

Write-DeploymentHeader "Azure Policy Deployment - Pre-flight Checks"

Write-DeploymentStep "Checking Azure CLI authentication..."
$account = az account show 2>&1 | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Not authenticated to Azure. Run 'az login' first."
}
Write-Information "  ✓ Authenticated as: $($account.user.name)"
Write-Information "  ✓ Tenant ID: $($account.tenantId)"

Write-DeploymentStep "Validating Bicep templates..."
$bicepFiles = @(
    (Join-Path $BicepRoot 'assignments/tenant/asb-tenant-root.bicep'),
    (Join-Path $BicepRoot 'assignments/management-groups/platform-identity/asb-platform-identity.bicep'),
    (Join-Path $BicepRoot 'assignments/management-groups/platform-connectivity/asb-platform-connectivity.bicep'),
    (Join-Path $BicepRoot 'assignments/management-groups/platform-management/asb-platform-management.bicep'),
    (Join-Path $BicepRoot 'assignments/management-groups/corp/asb-corp.bicep'),
    (Join-Path $BicepRoot 'assignments/management-groups/online/asb-online.bicep')
)

foreach ($bicepFile in $bicepFiles) {
    if (-not (Test-Path $bicepFile)) {
        throw "Bicep template not found: $bicepFile"
    }
}
Write-Information "  ✓ All Bicep templates validated"

# ============================================================================
# Deployment: Tenant Root Scope
# ============================================================================

if (-not $SkipTenantScope) {
    Write-DeploymentHeader "Phase 1: Tenant Root Deployment"
    
    $result = Invoke-PolicyDeployment `
        -Scope 'tenant' `
        -ScopeName 'Tenant Root' `
        -TemplateFile (Join-Path $BicepRoot 'assignments/tenant/asb-tenant-root.bicep') `
        -ParameterFile (Join-Path $ParamsRoot 'asb-tenant-root.params.json') `
        -DeploymentName "asb-tenant-root-$DeploymentTimestamp"
    
    $DeploymentResults += $result
    
    if ($result.Status -eq 'Failed') {
        Write-Warning "Tenant deployment failed. Continuing with management group deployments..."
    }
}
else {
    Write-Information "Skipping tenant scope deployment (SkipTenantScope flag set)"
}

# ============================================================================
# Deployment: Management Group Scopes
# ============================================================================

Write-DeploymentHeader "Phase 2: Management Group Deployments"

# Define management group deployment configuration
$mgDeployments = @(
    @{
        Name = 'platform-identity'
        DisplayName = 'Platform Identity'
        TemplateFile = 'assignments/management-groups/platform-identity/asb-platform-identity.bicep'
        ParameterFile = 'asb-platform-identity.params.json'
    },
    @{
        Name = 'platform-connectivity'
        DisplayName = 'Platform Connectivity'
        TemplateFile = 'assignments/management-groups/platform-connectivity/asb-platform-connectivity.bicep'
        ParameterFile = 'asb-platform-connectivity.params.json'
    },
    @{
        Name = 'platform-management'
        DisplayName = 'Platform Management'
        TemplateFile = 'assignments/management-groups/platform-management/asb-platform-management.bicep'
        ParameterFile = 'asb-platform-management.params.json'
    },
    @{
        Name = 'corp'
        DisplayName = 'Corp Landing Zones'
        TemplateFile = 'assignments/management-groups/corp/asb-corp.bicep'
        ParameterFile = 'asb-corp.params.json'
    },
    @{
        Name = 'online'
        DisplayName = 'Online Landing Zones'
        TemplateFile = 'assignments/management-groups/online/asb-online.bicep'
        ParameterFile = 'asb-online.params.json'
    }
)

# Filter deployments if TargetMGs specified
if ($TargetMGs) {
    $mgDeployments = $mgDeployments | Where-Object { $_.Name -in $TargetMGs }
    Write-Information "Targeting specific management groups: $($TargetMGs -join ', ')"
}

# Deploy to each management group sequentially
foreach ($mg in $mgDeployments) {
    $result = Invoke-PolicyDeployment `
        -Scope $mg.Name `
        -ScopeName $mg.DisplayName `
        -TemplateFile (Join-Path $BicepRoot $mg.TemplateFile) `
        -ParameterFile (Join-Path $ParamsRoot $mg.ParameterFile) `
        -DeploymentName "asb-$($mg.Name)-$DeploymentTimestamp"
    
    $DeploymentResults += $result
}

# ============================================================================
# Deployment Summary
# ============================================================================

Write-DeploymentHeader "Deployment Summary"

$successCount = ($DeploymentResults | Where-Object { $_.Status -eq 'Success' }).Count
$failureCount = ($DeploymentResults | Where-Object { $_.Status -eq 'Failed' }).Count

Write-Information ""
Write-Information "Total Deployments: $($DeploymentResults.Count)"
Write-Information "  ✓ Successful: $successCount"
if ($failureCount -gt 0) {
    Write-Information "  ✗ Failed: $failureCount"
}

Write-Information ""
Write-Information "Deployment Results:"
foreach ($result in $DeploymentResults) {
    $status = if ($result.Status -eq 'Success') { '✓' } else { '✗' }
    Write-Information "  $status $($result.Scope) - $($result.Status) ($($result.Duration)s)"
    if ($result.Status -eq 'Success') {
        Write-Information "    Assignment: $($result.AssignmentName) (Mode: $($result.EnforcementMode))"
    }
    else {
        Write-Information "    Error: $($result.Error)"
    }
}

# Save deployment log
$DeploymentResults | ConvertTo-Json -Depth 10 | Set-Content -Path $DeploymentLog
Write-Information ""
Write-Information "Deployment log saved: $DeploymentLog"

# ============================================================================
# Next Steps
# ============================================================================

Write-Information ""
Write-Information "============================================================================"
Write-Information "Next Steps:"
Write-Information "============================================================================"
Write-Information "1. Validate policy assignments in Azure Portal"
Write-Information "2. Run compliance validation: .\validate-policy-compliance.ps1"
Write-Information "3. Review compliance reports in: $GeneratedRoot"
Write-Information "4. Plan phased enforcement transition (audit → enforce)"
Write-Information ""

# Exit with appropriate code
if ($failureCount -gt 0) {
    exit 1
}
exit 0
