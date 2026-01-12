#Requires -Version 7.0
<#
.SYNOPSIS
    Diagnostic settings configuration functions

.DESCRIPTION
    Provides functions for configuring diagnostic settings on Azure resources.
    Handles idempotent creation of diagnostic settings with support for both
    categoryGroups (allLogs) and explicit category enumeration.
#>

# Import Common module for Write-Log
$modulePath = Join-Path $PSScriptRoot "Connectivity.Common.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force -ErrorAction SilentlyContinue
}

# Diagnostic Settings
function Ensure-DiagnosticSettings {
    <#
    .SYNOPSIS
        Creates diagnostic settings on an Azure resource if they don't exist
    
    .DESCRIPTION
        Configures diagnostic settings to send logs and metrics to a Log Analytics workspace.
        Handles resources that support categoryGroups (allLogs) and falls back to explicit
        category enumeration for older resource types.
        
        This function is idempotent - it will skip creation if the diagnostic setting
        already exists.
    
    .PARAMETER TargetResourceId
        The resource ID of the Azure resource to configure diagnostics for
    
    .PARAMETER LogAnalyticsWorkspaceResourceId
        The resource ID of the Log Analytics workspace to send diagnostics to
    
    .PARAMETER DiagnosticSettingName
        The name of the diagnostic setting to create
    
    .EXAMPLE
        Ensure-DiagnosticSettings `
            -TargetResourceId "/subscriptions/.../virtualHubs/vhub-australiaeast-001" `
            -LogAnalyticsWorkspaceResourceId "/subscriptions/.../workspaces/law-rai-prod-aue-platform-01" `
            -DiagnosticSettingName "diag-vhub"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TargetResourceId,
        
        [Parameter(Mandatory)]
        [string]$LogAnalyticsWorkspaceResourceId,
        
        [Parameter(Mandatory)]
        [string]$DiagnosticSettingName
    )

    # Check if already exists
    $existing = az monitor diagnostic-settings list `
        --resource $TargetResourceId `
        --query "value[?name=='$DiagnosticSettingName'].name | [0]" `
        -o tsv 2>$null

    if ($existing) {
        Write-Log "Diagnostic setting '$DiagnosticSettingName' already exists on resource. Skipping." -Level "INFO"
        return
    }

    # Verify supported categories
    try {
        $catsJson = az monitor diagnostic-settings categories list --resource $TargetResourceId -o json 2>$null
        if (!$catsJson) {
            Write-Log "Failed to retrieve diagnostic categories for resource. Skipping diagnostic settings." -Level "WARN"
            return
        }
        
        $cats = $catsJson | ConvertFrom-Json
        if (!$cats -or !$cats.value) {
            Write-Log "No diagnostic categories found for resource. Skipping diagnostic settings." -Level "WARN"
            return
        }
    }
    catch {
        Write-Log "Error retrieving diagnostic categories: $_" -Level "WARN"
        return
    }

    $hasAllLogsGroup = $false
    foreach ($c in $cats.value) {
        # Safely check if categoryGroups property exists and contains "allLogs"
        if ($c.PSObject.Properties.Name -contains "categoryGroups" -and $null -ne $c.categoryGroups) {
            if ($c.categoryGroups -is [array] -and ($c.categoryGroups -contains "allLogs")) { 
                $hasAllLogsGroup = $true 
                break
            }
        }
    }

    if ($hasAllLogsGroup) {
        az monitor diagnostic-settings create `
            --name $DiagnosticSettingName `
            --resource $TargetResourceId `
            --workspace $LogAnalyticsWorkspaceResourceId `
            --metrics '[{"category":"AllMetrics","enabled":true}]' `
            --logs '[{"categoryGroup":"allLogs","enabled":true}]' `
            --only-show-errors | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Diagnostic setting '$DiagnosticSettingName' created with categoryGroup 'allLogs'." -Level "SUCCESS"
        } else {
            Write-Log "Failed to create diagnostic setting '$DiagnosticSettingName'. Exit code: $LASTEXITCODE" -Level "WARN"
        }
    }
    else {
        # Fallback: enable all log categories explicitly (safe)
        $logCats = @()
        foreach ($c in $cats.value) {
            # Safely check properties exist before accessing
            if ($c.PSObject.Properties.Name -contains "categoryType" -and 
                $c.PSObject.Properties.Name -contains "name" -and
                $c.categoryType -eq "Logs" -and $c.name) { 
                $logCats += @{ category = $c.name; enabled = $true }
            }
        }
        
        if ($logCats.Count -eq 0) {
            Write-Log "No log categories found for resource. Skipping diagnostic settings." -Level "WARN"
            return
        }
        
        $logsJson = ($logCats | ConvertTo-Json -Compress -Depth 10)

        az monitor diagnostic-settings create `
            --name $DiagnosticSettingName `
            --resource $TargetResourceId `
            --workspace $LogAnalyticsWorkspaceResourceId `
            --metrics '[{"category":"AllMetrics","enabled":true}]' `
            --logs $logsJson `
            --only-show-errors | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Diagnostic setting '$DiagnosticSettingName' created with explicit log categories." -Level "SUCCESS"
        } else {
            Write-Log "Failed to create diagnostic setting '$DiagnosticSettingName'. Exit code: $LASTEXITCODE" -Level "WARN"
        }
    }
}

Export-ModuleMember -Function Ensure-DiagnosticSettings
