#Requires -Version 7.0
<#
.SYNOPSIS
    Common utility functions for connectivity deployments

.DESCRIPTION
    Provides shared functions for logging, configuration loading, Bicep module restoration,
    and retry logic. Does not contain Azure resource deployment or diagnostic settings.
#>

# Logging
function Write-Log {
    <#
    .SYNOPSIS
        Writes a timestamped log message with color coding
    
    .PARAMETER Message
        The message to log (accepts any object type and converts to string)
    
    .PARAMETER Level
        Log level: INFO, WARN, ERROR, SUCCESS
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    # Convert message to string safely (handles arrays, objects, null, etc.)
    $messageText = if ($null -eq $Message) { 
        "" 
    } 
    else { 
        ($Message | Out-String).TrimEnd() 
    }
    
    # Handle empty output
    if ([string]::IsNullOrWhiteSpace($messageText)) {
        $messageText = "(no message content)"
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $messageText" -ForegroundColor $color
}

# Subscription & Configuration
function Normalize-SubscriptionId {
    <#
    .SYNOPSIS
        Normalizes subscription ID formats to a consistent GUID format
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )
    
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

function Get-ConnectivityConfig {
    <#
    .SYNOPSIS
        Loads connectivity configuration from JSON file
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigFile
    )
    
    if ([string]::IsNullOrWhiteSpace($ConfigFile)) {
        $modulePath = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.PSCommandPath }
        $scriptsDir = Split-Path $modulePath -Parent
        $connectivityDir = Split-Path $scriptsDir -Parent
        $ConfigFile = Join-Path $connectivityDir "config/connectivity.prod.json"
    }
    
    if (!(Test-Path $ConfigFile)) {
        Write-Log "Connectivity config file not found: $ConfigFile" -Level "WARN"
        return $null
    }
    
    try {
        $config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        if ($config.connectivityConfig) {
            return $config.connectivityConfig
        }
    }
    catch {
        Write-Log "Failed to load connectivity config: $_" -Level "WARN"
    }
    
    return $null
}


# Bicep Module Restoration
function Restore-BicepModules {
    <#
    .SYNOPSIS
        Restores Bicep module dependencies by building the template
    #>
    param(
        [Parameter(Mandatory)]
        [string]$BicepFile
    )
    
    Write-Log "Restoring Bicep modules for $BicepFile" -Level "INFO"
    az bicep build --file $BicepFile --outfile /dev/null 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Warning: Bicep module restore had issues, but continuing..." -Level "WARN"
    }
}

# Retry Logic
function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a command with exponential backoff retry for transient errors
    
    .DESCRIPTION
        Retries commands that fail with Firewall Policy RCG lock errors.
        Uses exponential backoff with a maximum delay of 5 minutes.
    #>
    param (
        [Parameter(Mandatory)]
        [scriptblock]$Command,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 6,
        
        [Parameter(Mandatory = $false)]
        [int]$InitialDelaySeconds = 30
    )

    $attempt = 1
    $delay = $InitialDelaySeconds

    while ($true) {
        try {
            & $Command
            if ($LASTEXITCODE -ne 0) {
                $errorOutput = $Error[0].Exception.Message
                throw "Command failed with exit code $LASTEXITCODE : $errorOutput"
            }
            return
        }
        catch {
            $errorMessage = $_.Exception.Message

            # Only retry on Azure Firewall Policy RCG lock error
            if ($errorMessage -match "FirewallPolicyRuleCollectionGroupUpdateNotAllowedWhenUpdatingOrDeleting") {

                if ($attempt -ge $MaxRetries) {
                    Write-Log "Firewall Policy deployment failed after $attempt attempts due to persistent RCG update lock." -Level "ERROR"
                    throw
                }

                Write-Log "Firewall Policy RCG is locked (attempt $attempt of $MaxRetries). Waiting $delay seconds before retry..." -Level "WARN"
                Start-Sleep -Seconds $delay

                $attempt++
                $delay = [Math]::Min($delay * 2, 300) # cap backoff at 5 minutes
            }
            else {
                # Any other error is real and should fail immediately
                throw
            }
        }
    }
}

Export-ModuleMember -Function Write-Log, Normalize-SubscriptionId, Get-ConnectivityConfig, `
    Restore-BicepModules, Invoke-WithRetry
