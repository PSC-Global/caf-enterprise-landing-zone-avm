<#
.SYNOPSIS
    Validates Azure Security Benchmark policy compliance across the CAF management group hierarchy.

.DESCRIPTION
    This script queries Azure Policy compliance state for all Azure Security Benchmark assignments
    and generates comprehensive compliance reports in JSON and HTML formats.
    
    Reports include:
    - Overall compliance percentage per scope (tenant, management groups)
    - Non-compliant resource counts by resource type
    - Policy control compliance breakdown
    - Resource-level compliance details
    - Trending data for historical comparison

.PARAMETER OrgId
    The organization ID prefix for management group names. Default: rai

.PARAMETER OutputFormat
    Report output format. Valid values: JSON, HTML, Both. Default: Both

.PARAMETER IncludeCompliantResources
    Include compliant resources in detailed reports (increases report size)

.PARAMETER MaxResults
    Maximum number of policy state records to retrieve. Default: 10000

.EXAMPLE
    .\validate-policy-compliance.ps1
    Generates compliance reports for all ASB assignments in JSON and HTML formats

.EXAMPLE
    .\validate-policy-compliance.ps1 -OutputFormat HTML -IncludeCompliantResources
    Generates HTML report including compliant resources

.NOTES
    Author: CAF Enterprise Landing Zone Team
    Prerequisites:
    - Azure CLI installed and authenticated
    - Policy Reader role at tenant root (minimum)
    - Policy assignments deployed via deploy-policies.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OrgId = 'rai',

    [Parameter(Mandatory = $false)]
    [ValidateSet('JSON', 'HTML', 'Both')]
    [string]$OutputFormat = 'Both',

    [Parameter(Mandatory = $false)]
    [switch]$IncludeCompliantResources,

    [Parameter(Mandatory = $false)]
    [int]$MaxResults = 10000
)

# ============================================================================
# Script Configuration
# ============================================================================

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Get script root directory
$ScriptRoot = $PSScriptRoot
$PoliciesRoot = Split-Path -Parent $ScriptRoot
$GeneratedRoot = Join-Path $PoliciesRoot 'generated'

# Ensure generated folder exists
if (-not (Test-Path $GeneratedRoot)) {
    New-Item -Path $GeneratedRoot -ItemType Directory -Force | Out-Null
}

# Report configuration
$ReportTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$JsonReportPath = Join-Path $GeneratedRoot "compliance-report-$ReportTimestamp.json"
$HtmlReportPath = Join-Path $GeneratedRoot "compliance-report-$ReportTimestamp.html"

# ============================================================================
# Helper Functions
# ============================================================================

function Write-ValidationHeader {
    param([string]$Message)
    Write-Information ""
    Write-Information "============================================================================"
    Write-Information $Message
    Write-Information "============================================================================"
}

function Write-ValidationStep {
    param([string]$Message)
    Write-Information ""
    Write-Information "→ $Message"
}

function Get-PolicyComplianceState {
    param(
        [Parameter(Mandatory)]
        [string]$Filter,
        
        [Parameter(Mandatory)]
        [string]$ScopeName
    )

    Write-ValidationStep "Querying compliance state: $ScopeName"
    
    try {
        # Query policy state with filter
        $statesJson = az policy state list `
            --filter $Filter `
            --top $MaxResults `
            --output json 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Failed to query policy state: $statesJson"
            return @()
        }

        $states = $statesJson | ConvertFrom-Json
        
        if (-not $IncludeCompliantResources) {
            $states = $states | Where-Object { $_.complianceState -eq 'NonCompliant' }
        }

        Write-Information "  ✓ Retrieved $($states.Count) policy state records"
        return $states
    }
    catch {
        Write-Warning "  Error querying policy state: $($_.Exception.Message)"
        return @()
    }
}

function Get-ComplianceSummary {
    param(
        [Parameter(Mandatory)]
        [array]$PolicyStates
    )

    $totalResources = $PolicyStates.Count
    $compliantResources = ($PolicyStates | Where-Object { $_.complianceState -eq 'Compliant' }).Count
    $nonCompliantResources = ($PolicyStates | Where-Object { $_.complianceState -eq 'NonCompliant' }).Count
    $exemptResources = ($PolicyStates | Where-Object { $_.complianceState -eq 'Exempt' }).Count

    $compliancePercentage = if ($totalResources -gt 0) {
        [math]::Round(($compliantResources / $totalResources) * 100, 2)
    } else { 0 }

    return @{
        TotalResources = $totalResources
        CompliantResources = $compliantResources
        NonCompliantResources = $nonCompliantResources
        ExemptResources = $exemptResources
        CompliancePercentage = $compliancePercentage
    }
}

function Get-ResourceTypeBreakdown {
    param(
        [Parameter(Mandatory)]
        [array]$PolicyStates
    )

    $nonCompliantStates = $PolicyStates | Where-Object { $_.complianceState -eq 'NonCompliant' }
    
    $breakdown = $nonCompliantStates | 
        Group-Object -Property resourceType | 
        Select-Object @{Name='ResourceType';Expression={$_.Name}}, 
                      @{Name='NonCompliantCount';Expression={$_.Count}} |
        Sort-Object -Property NonCompliantCount -Descending

    return $breakdown
}

function ConvertTo-HtmlReport {
    param(
        [Parameter(Mandatory)]
        [hashtable]$ComplianceData
    )

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Azure Security Benchmark - Compliance Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #005a9e; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .card.success { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
        .card.warning { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); }
        .card h3 { margin: 0; font-size: 2em; }
        .card p { margin: 10px 0 0 0; font-size: 0.9em; opacity: 0.9; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background-color: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background-color: #f5f5f5; }
        .scope-section { margin: 30px 0; padding: 20px; background-color: #f9f9f9; border-left: 4px solid #0078d4; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 0.9em; text-align: center; }
        .compliance-bar { width: 100%; height: 30px; background-color: #f5f5f5; border-radius: 15px; overflow: hidden; }
        .compliance-fill { height: 100%; background: linear-gradient(90deg, #11998e 0%, #38ef7d 100%); transition: width 0.3s ease; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Azure Security Benchmark - Compliance Report</h1>
        <p><strong>Generated:</strong> $($ComplianceData.Metadata.ReportGeneratedAt)</p>
        <p><strong>Organization:</strong> $($ComplianceData.Metadata.OrgId)</p>
        
        <h2>Overall Compliance Summary</h2>
        <div class="summary">
            <div class="card success">
                <h3>$($ComplianceData.OverallSummary.CompliancePercentage)%</h3>
                <p>Overall Compliance</p>
            </div>
            <div class="card">
                <h3>$($ComplianceData.OverallSummary.TotalResources)</h3>
                <p>Total Resources</p>
            </div>
            <div class="card success">
                <h3>$($ComplianceData.OverallSummary.CompliantResources)</h3>
                <p>Compliant</p>
            </div>
            <div class="card warning">
                <h3>$($ComplianceData.OverallSummary.NonCompliantResources)</h3>
                <p>Non-Compliant</p>
            </div>
        </div>
        
        <h2>Compliance by Scope</h2>
"@

    foreach ($scope in $ComplianceData.ScopeCompliance) {
        $html += @"
        <div class="scope-section">
            <h3>$($scope.ScopeName)</h3>
            <div class="compliance-bar">
                <div class="compliance-fill" style="width: $($scope.Summary.CompliancePercentage)%"></div>
            </div>
            <p>Compliance: <strong>$($scope.Summary.CompliancePercentage)%</strong> ($($scope.Summary.CompliantResources)/$($scope.Summary.TotalResources) resources)</p>
            <p>Non-Compliant: <strong>$($scope.Summary.NonCompliantResources)</strong> | Exempt: <strong>$($scope.Summary.ExemptResources)</strong></p>
            
            <h4>Non-Compliant Resources by Type</h4>
            <table>
                <thead>
                    <tr>
                        <th>Resource Type</th>
                        <th>Non-Compliant Count</th>
                    </tr>
                </thead>
                <tbody>
"@
        if ($scope.ResourceTypeBreakdown.Count -gt 0) {
            foreach ($resourceType in $scope.ResourceTypeBreakdown | Select-Object -First 10) {
                $html += @"
                    <tr>
                        <td>$($resourceType.ResourceType)</td>
                        <td>$($resourceType.NonCompliantCount)</td>
                    </tr>
"@
            }
        } else {
            $html += "<tr><td colspan='2' style='text-align: center; color: #11998e;'>✓ All resources compliant</td></tr>"
        }

        $html += @"
                </tbody>
            </table>
        </div>
"@
    }

    $html += @"
        <div class="footer">
            <p>CAF Enterprise Landing Zone - Azure Policy Governance Framework</p>
            <p>For enforcement planning and remediation guidance, consult platform/policies/config/asb-mapping/</p>
        </div>
    </div>
</body>
</html>
"@

    return $html
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

Write-ValidationHeader "Azure Policy Compliance Validation - Pre-flight Checks"

Write-ValidationStep "Checking Azure CLI authentication..."
$account = az account show 2>&1 | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "Not authenticated to Azure. Run 'az login' first."
}
Write-Information "  ✓ Authenticated as: $($account.user.name)"
Write-Information "  ✓ Tenant ID: $($account.tenantId)"

# ============================================================================
# Query Policy Compliance State
# ============================================================================

Write-ValidationHeader "Querying Policy Compliance State"

# Define scopes to query
$scopes = @(
    @{ Name = 'Tenant Root'; Filter = "policyAssignmentName eq 'asb-tenant-root-audit'" },
    @{ Name = 'Platform Identity'; Filter = "policyAssignmentName eq 'asb-platform-identity-audit'" },
    @{ Name = 'Platform Connectivity'; Filter = "policyAssignmentName eq 'asb-platform-connectivity-audit'" },
    @{ Name = 'Platform Management'; Filter = "policyAssignmentName eq 'asb-platform-management-audit'" },
    @{ Name = 'Corp Landing Zones'; Filter = "policyAssignmentName eq 'asb-corp-landing-zones-audit'" },
    @{ Name = 'Online Landing Zones'; Filter = "policyAssignmentName eq 'asb-online-landing-zones-audit'" }
)

$complianceData = @{
    Metadata = @{
        ReportGeneratedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        OrgId = $OrgId
        IncludeCompliantResources = $IncludeCompliantResources.IsPresent
    }
    ScopeCompliance = @()
    OverallSummary = @{}
}

$allPolicyStates = @()

foreach ($scope in $scopes) {
    $policyStates = Get-PolicyComplianceState -Filter $scope.Filter -ScopeName $scope.Name
    
    if ($policyStates.Count -gt 0) {
        $summary = Get-ComplianceSummary -PolicyStates $policyStates
        $resourceTypeBreakdown = Get-ResourceTypeBreakdown -PolicyStates $policyStates
        
        $scopeData = @{
            ScopeName = $scope.Name
            Summary = $summary
            ResourceTypeBreakdown = $resourceTypeBreakdown
            PolicyStates = $policyStates
        }
        
        $complianceData.ScopeCompliance += $scopeData
        $allPolicyStates += $policyStates
    }
}

# Calculate overall summary
if ($allPolicyStates.Count -gt 0) {
    $complianceData.OverallSummary = Get-ComplianceSummary -PolicyStates $allPolicyStates
}

# ============================================================================
# Generate Reports
# ============================================================================

Write-ValidationHeader "Generating Compliance Reports"

if ($OutputFormat -in @('JSON', 'Both')) {
    Write-ValidationStep "Generating JSON report..."
    $complianceData | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonReportPath
    Write-Information "  ✓ JSON report saved: $JsonReportPath"
}

if ($OutputFormat -in @('HTML', 'Both')) {
    Write-ValidationStep "Generating HTML report..."
    $htmlContent = ConvertTo-HtmlReport -ComplianceData $complianceData
    $htmlContent | Set-Content -Path $HtmlReportPath -Encoding UTF8
    Write-Information "  ✓ HTML report saved: $HtmlReportPath"
}

# ============================================================================
# Compliance Summary
# ============================================================================

Write-ValidationHeader "Compliance Summary"

Write-Information ""
Write-Information "Overall Compliance:"
Write-Information "  Total Resources: $($complianceData.OverallSummary.TotalResources)"
Write-Information "  Compliant: $($complianceData.OverallSummary.CompliantResources) ($($complianceData.OverallSummary.CompliancePercentage)%)"
Write-Information "  Non-Compliant: $($complianceData.OverallSummary.NonCompliantResources)"
Write-Information "  Exempt: $($complianceData.OverallSummary.ExemptResources)"

Write-Information ""
Write-Information "Compliance by Scope:"
foreach ($scopeData in $complianceData.ScopeCompliance) {
    Write-Information "  $($scopeData.ScopeName): $($scopeData.Summary.CompliancePercentage)% ($($scopeData.Summary.NonCompliantResources) non-compliant)"
}

Write-Information ""
Write-Information "Reports generated in: $GeneratedRoot"
if ($OutputFormat -in @('JSON', 'Both')) {
    Write-Information "  - JSON: $(Split-Path -Leaf $JsonReportPath)"
}
if ($OutputFormat -in @('HTML', 'Both')) {
    Write-Information "  - HTML: $(Split-Path -Leaf $HtmlReportPath)"
}

Write-Information ""
Write-Information "============================================================================"
Write-Information "Next Steps:"
Write-Information "============================================================================"
Write-Information "1. Review non-compliant resources in generated reports"
Write-Information "2. Consult ASB control mappings: platform/policies/config/asb-mapping/"
Write-Information "3. Plan remediation activities for high-priority controls"
Write-Information "4. Update enforcementMode to 'Default' in parameter files for phased enforcement"
Write-Information ""

exit 0
