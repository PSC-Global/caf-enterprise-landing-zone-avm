#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys networking infrastructure (vWAN hub or spoke vNet) for a subscription
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "../../../subscription-vending/config/subscriptions.json",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("hub", "spoke", "workload", "ingress")]
    [string]$Role,
    
    [Parameter(Mandatory = $false)]
    [string]$HubSubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$HubResourceGroup,
    
    [Parameter(Mandatory = $false)]
    [string]$HubName,
    
    [Parameter(Mandatory = $false)]
    [switch]$DeployAll = $true,
    
    [Parameter(Mandatory = $false)]
    [switch]$DeployHubCore,
    
    [Parameter(Mandatory = $false)]
    [switch]$DeployFirewall,
    
    [Parameter(Mandatory = $false)]
    [switch]$DeployFirewallPolicy,
    
    [Parameter(Mandatory = $false)]
    [switch]$DeployRouting,
    
    [Parameter(Mandatory = $false)]
    [switch]$DeployPrivateDns,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('RoutingIntent', 'CustomRouteTables')]
    [string]$RoutingMode = 'RoutingIntent'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$IsWhatIf = $PSCmdlet.MyInvocation.BoundParameters.ContainsKey('WhatIf')

$scriptPath = if ($MyInvocation.PSCommandPath) { $MyInvocation.PSCommandPath } else { $PSCommandPath }
if (!$scriptPath) {
    throw "Cannot determine script path. This script must be executed directly, not dot-sourced."
}
$scriptDir = Split-Path -Parent $scriptPath
if (!$scriptDir) {
    $scriptDir = $PWD.Path
}
$libPath = Join-Path $scriptDir "lib"
Import-Module (Join-Path $libPath "Connectivity.psd1") -Force

Write-Log "Loading configuration from $ConfigFile"

if (!(Test-Path $ConfigFile)) {
    Write-Log "Configuration file not found: $ConfigFile" -Level "ERROR"
    exit 1
}

$config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$subscription = $config.subscriptions | Where-Object { $_.aliasName -eq $SubscriptionId -or $_.displayName -eq $SubscriptionId }

if (!$subscription) {
    Write-Log "Subscription '$SubscriptionId' not found in configuration" -Level "ERROR"
    exit 1
}

$subscriptionRole = if ($Role) { $Role } else { $subscription.role }

if ($subscriptionRole -notin @("hub", "spoke", "workload")) {
    Write-Log "Subscription role '$subscriptionRole' does not require networking. Exiting." -Level "INFO"
    exit 0
}

Write-Log "Deploying connectivity for subscription: $($subscription.displayName)"
Write-Log "Role: $subscriptionRole"
Write-Log "Primary region: $($subscription.primaryRegion)"

# Resolve Azure subscription ID using REST API (same method as deploy-mg-alias.ps1)
try {
    $azSubscriptionId = az rest --method GET `
        --uri "https://management.azure.com/providers/Microsoft.Subscription/aliases/$($subscription.aliasName)?api-version=2021-10-01" `
        --query "properties.subscriptionId" -o tsv 2>$null
}
catch {
    $azSubscriptionId = $null
}

if ([string]::IsNullOrWhiteSpace($azSubscriptionId)) {
    Write-Log "Could not find Azure subscription for alias '$($subscription.aliasName)'." -Level "ERROR"
    Write-Log "Please ensure the subscription was created via deploy-mg-alias.ps1 first." -Level "ERROR"
    exit 1
}

$azSubscriptionId = Normalize-SubscriptionId -SubscriptionId $azSubscriptionId
Write-Log "Using Azure Subscription ID: $azSubscriptionId" -Level "INFO"

az account set --subscription $azSubscriptionId | Out-Null

$subscriptionPurpose = switch ($subscriptionRole) {
    "hub" { "core" }
    default {
        if ($subscription.aliasName -match "fraud-engine") { "fraud-engine" }
        elseif ($subscription.aliasName -match "lending-core") { "lending-core" }
        else { "workload" }
    }
}

Write-Log "Phase 1: Creating networking resource group" -Level "SUCCESS"

$networkingRgName = "rg-$subscriptionPurpose-network-$($subscription.primaryRegion)-001"

try {
    Ensure-ResourceGroup `
        -SubscriptionId $azSubscriptionId `
        -Location $subscription.primaryRegion `
        -ResourceGroupName $networkingRgName `
        -PrimaryRegion $subscription.primaryRegion `
        -SubscriptionPurpose $subscriptionPurpose `
        -Tags $subscription.tags `
        -SubscriptionAlias $subscription.aliasName `
        -IsWhatIf $IsWhatIf
}
catch {
    Write-Log "Failed to create networking resource group: $_" -Level "ERROR"
    exit 1
}

if ($subscriptionRole -eq "hub") {
    $isStageMode = $DeployHubCore -or $DeployFirewall -or $DeployFirewallPolicy -or $DeployRouting -or $DeployPrivateDns
    
    if ($isStageMode) {
        $DeployAll = $false
        Write-Log "Stage-based deployment mode detected. DeployAll forced to false." -Level "INFO"
    }
    
    $shouldDeployHubCore = $DeployAll -or $DeployHubCore
    $shouldDeployFirewallPolicy = $DeployAll -or $DeployFirewallPolicy
    $shouldDeployFirewall = $DeployAll -or $DeployFirewall
    $shouldDeployRouting = $DeployAll -or ($DeployRouting -and $RoutingMode -eq 'RoutingIntent')
    $shouldDeployPrivateDns = $DeployAll -or $DeployPrivateDns
    
    if ($RoutingMode -eq 'CustomRouteTables' -and ($shouldDeployRouting -or $DeployAll)) {
        Write-Log "ERROR: CustomRouteTables routing mode is not yet implemented. Only RoutingIntent is supported." -Level "ERROR"
        Write-Log "Use -RoutingMode 'RoutingIntent' (default) or remove routing deployment." -Level "ERROR"
        exit 1
    }
    
    Write-Log "Routing Mode: $RoutingMode" -Level "INFO"
    
    if ($isStageMode) {
        Write-Log "Stage-based deployment enabled. Deploying only specified stages." -Level "INFO"
        Write-Log "Stages: HubCore=$shouldDeployHubCore, FirewallPolicy=$shouldDeployFirewallPolicy, Firewall=$shouldDeployFirewall, Routing=$shouldDeployRouting, PrivateDns=$shouldDeployPrivateDns" -Level "INFO"
    } else {
        Write-Log "Full deployment mode (backward compatible - using vwan-hub.bicep orchestrator)" -Level "INFO"
    }
    
    Write-Log "Phase 2: Deploying vWAN hub" -Level "SUCCESS"
    
    try {
        Invoke-HubDeployment `
            -SubscriptionId $azSubscriptionId `
            -ResourceGroup $networkingRgName `
            -Subscription $subscription `
            -Config $config `
            -DeployAll $DeployAll `
            -DeployHubCore $shouldDeployHubCore `
            -DeployFirewallPolicy $shouldDeployFirewallPolicy `
            -DeployFirewall $shouldDeployFirewall `
            -DeployRouting $shouldDeployRouting `
            -DeployPrivateDns $shouldDeployPrivateDns `
            -RoutingMode $RoutingMode `
            -IsWhatIf $IsWhatIf
    }
    catch {
        Write-Log "Hub deployment failed: $_" -Level "ERROR"
        exit 1
    }
}

elseif ($subscriptionRole -in @("spoke", "workload")) {
    Write-Log "Phase 2: Deploying spoke vNet" -Level "SUCCESS"
    
    try {
        Invoke-SpokeDeployment `
            -SubscriptionId $azSubscriptionId `
            -ResourceGroup $networkingRgName `
            -Subscription $subscription `
            -Config $config `
            -HubSubscriptionId $HubSubscriptionId `
            -HubResourceGroup $HubResourceGroup `
            -HubName $HubName `
            -SubscriptionPurpose $subscriptionPurpose `
            -IsWhatIf $IsWhatIf
    }
    catch {
        Write-Log "Spoke deployment failed: $_" -Level "ERROR"
        exit 1
    }
}

Write-Log "Connectivity deployment completed successfully" -Level "SUCCESS"
Write-Log "Subscription: $($subscription.displayName)"
Write-Log "Azure Sub ID: $azSubscriptionId"
Write-Log "Networking RG: $networkingRgName"
Write-Host ""
Write-Log "Next steps:"
Write-Log "1. Configure firewall rules (for hub deployments)"
Write-Log "2. Set up VPN connections (if needed)"
Write-Log "3. Verify hub-spoke connectivity"
