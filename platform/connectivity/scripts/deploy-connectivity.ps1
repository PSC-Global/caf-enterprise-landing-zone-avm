#Requires -Version 7.0
<#
.SYNOPSIS
    Deploys networking infrastructure (vWAN hub or spoke vNet) for a subscription
    
.DESCRIPTION
    Standalone script to deploy networking resources for a subscription.
    Can be run independently after subscription creation and bootstrap.
    
    Supports:
    - vWAN hub deployment (for hub role subscriptions)
    - Spoke vNet deployment (for spoke/workload role subscriptions)
    - Automatic hub discovery for spoke connections
    
.PARAMETER SubscriptionId
    Azure subscription ID or aliasName to deploy networking to
    
.PARAMETER ConfigFile
    Path to subscriptions.json configuration file
    
.PARAMETER Role
    Subscription role: "hub" or "spoke" (auto-detected from config if not specified)
    
.PARAMETER HubSubscriptionId
    Azure subscription ID of the hub subscription (for spoke deployments)
    
.PARAMETER HubResourceGroup
    Resource group name containing the virtual hub (for spoke deployments)
    
.PARAMETER HubName
    Virtual hub name (for spoke deployments)
    
.EXAMPLE
    ./deploy-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01"
    Deploys vWAN hub for platform-connectivity subscription
    
.EXAMPLE
    ./deploy-connectivity.ps1 -SubscriptionId "rai-fraud-engine-prod-01" -HubSubscriptionId "xxx" -HubResourceGroup "rg-network-core-network-australiaeast-001" -HubName "vhub-australiaeast-001"
    Deploys spoke vNet for fraud-engine subscription with explicit hub connection
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "../../subscription-vending/config/subscriptions.json",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("hub", "spoke", "workload")]
    [string]$Role,
    
    [Parameter(Mandatory = $false)]
    [string]$HubSubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$HubResourceGroup,
    
    [Parameter(Mandatory = $false)]
    [string]$HubName
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

function Get-IpamConfig {
    param([string]$AliasName)
    
    $ipamConfigFile = "../config/ipam.json"
    if (!(Test-Path $ipamConfigFile)) {
        Write-Log "IPAM config file not found: $ipamConfigFile" -Level "WARN"
        return $null
    }
    
    try {
        $ipamConfig = Get-Content $ipamConfigFile -Raw | ConvertFrom-Json
        if ($ipamConfig.ipamConfig -and $ipamConfig.ipamConfig.$AliasName) {
            return $ipamConfig.ipamConfig.$AliasName
        }
    }
    catch {
        Write-Log "Failed to load IPAM config: $_" -Level "WARN"
    }
    
    return $null
}

function Resolve-IpamBlock {
    param(
        [string]$BlockName,
        [string]$Space,
        [int]$SizeHint
    )
    
    # If block looks like a CIDR (contains /), return as-is
    if ($BlockName -match '^\d+\.\d+\.\d+\.\d+/\d+$') {
        Write-Log "Block '$BlockName' is already a CIDR prefix" -Level "INFO"
        return $BlockName
    }
    
    # Otherwise, try to resolve from IPAM mapping or use defaults
    $ipamMapping = @{
        "rai-hub-aue" = "10.0.0.0/20"
        "rai-hub-ause" = "10.0.16.0/20"
        "rai-platform-mgmt" = "10.5.0.0/22"
        "rai-platform-identity" = "10.5.4.0/23"
        "rai-platform-sharedsvc" = "10.5.6.0/24"
    }
    
    if ($ipamMapping.ContainsKey($BlockName)) {
        Write-Log "Resolved IPAM block '$BlockName' to CIDR: $($ipamMapping[$BlockName])" -Level "INFO"
        return $ipamMapping[$BlockName]
    }
    
    # If not found, generate a warning and return a placeholder
    Write-Log "IPAM block '$BlockName' not found in mapping. Please add to IPAM or provide CIDR directly." -Level "WARN"
    Write-Log "Using placeholder CIDR based on size hint: /$SizeHint" -Level "WARN"
    return "10.1.0.0/$SizeHint"
}

function Get-HubResourceId {
    param(
        [string]$SubscriptionId,
        [string]$ResourceGroup,
        [string]$HubName
    )
    
    try {
        $hub = az network vhub show `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $HubName `
            --query id -o tsv 2>$null
        
        if ($hub) {
            return $hub
        }
    }
    catch {
        Write-Log "Failed to get hub resource ID: $_" -Level "WARN"
    }
    
    return $null
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
$subscription = $config.subscriptions | Where-Object { $_.aliasName -eq $SubscriptionId -or $_.displayName -eq $SubscriptionId }

if (!$subscription) {
    Write-Log "Subscription '$SubscriptionId' not found in configuration" -Level "ERROR"
    exit 1
}

# Determine role
$subscriptionRole = if ($Role) { $Role } else { $subscription.role }

if ($subscriptionRole -notin @("hub", "spoke", "workload")) {
    Write-Log "Subscription role '$subscriptionRole' does not require networking. Exiting." -Level "INFO"
    exit 0
}

Write-Log "Deploying connectivity for subscription: $($subscription.displayName)"
Write-Log "Role: $subscriptionRole"
Write-Log "Primary region: $($subscription.primaryRegion)"

# Resolve Azure subscription ID
$azSubscriptionId = (az account subscription alias show --name $subscription.aliasName --query "properties.subscriptionId" -o tsv 2>$null)

if ([string]::IsNullOrWhiteSpace($azSubscriptionId)) {
    Write-Log "Could not find Azure subscription for alias '$($subscription.aliasName)'." -Level "ERROR"
    Write-Log "Please ensure the subscription was created via deploy-mg-alias.ps1 first." -Level "ERROR"
    exit 1
}

$azSubscriptionId = Normalize-SubscriptionId -SubscriptionId $azSubscriptionId
Write-Log "Using Azure Subscription ID: $azSubscriptionId" -Level "INFO"

# Set subscription context
az account set --subscription $azSubscriptionId | Out-Null

# Derive subscription purpose for naming
$subscriptionPurpose = switch ($subscriptionRole) {
    "hub" { "network-core" }
    default {
        if ($subscription.aliasName -match "fraud-engine") { "fraud-engine" }
        elseif ($subscription.aliasName -match "lending-core") { "lending-core" }
        else { "workload" }
    }
}

# =============================================================================
# Phase 1: Create Networking Resource Group
# =============================================================================

Write-Log "Phase 1: Creating networking resource group" -Level "SUCCESS"

$networkingRgName = "rg-$subscriptionPurpose-network-$($subscription.primaryRegion)-001"

if ($IsWhatIf) {
    Write-Log "WhatIf: Would create networking resource group: $networkingRgName" -Level "WARN"
} else {
    try {
        Restore-BicepModules -BicepFile "../bicep/resource-group.bicep"
        
        $rgParams = @(
            "primaryRegion=$($subscription.primaryRegion)",
            "subscriptionPurpose=$subscriptionPurpose",
            "tags=$($subscription.tags | ConvertTo-Json -Compress)"
        )
        
        az deployment sub create `
            --subscription $azSubscriptionId `
            --location $subscription.primaryRegion `
            --name "rg-network-$($subscription.aliasName)-$(Get-Date -Format 'yyyyMMddHHmmss')" `
            --template-file "../bicep/resource-group.bicep" `
            --parameters $rgParams `
            --output json | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Resource group deployment failed with exit code $LASTEXITCODE"
        }
        
        Write-Log "Networking resource group created: $networkingRgName" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to create networking resource group: $_" -Level "ERROR"
        exit 1
    }
}

# =============================================================================
# Phase 2: Deploy vWAN Hub (for hub role)
# =============================================================================

if ($subscriptionRole -eq "hub") {
    Write-Log "Phase 2: Deploying vWAN hub" -Level "SUCCESS"
    
    # Load IPAM config
    $ipamConfig = Get-IpamConfig -AliasName $subscription.aliasName
    if (!$ipamConfig) {
        Write-Log "Hub subscription requires IPAM configuration. Add entry for '$($subscription.aliasName)' in config/ipam.json" -Level "ERROR"
        exit 1
    }
    
    Write-Log "Deploying vWAN hub for region $($subscription.primaryRegion)"
    
    $vwanName = "vwan-$($subscription.primaryRegion)"
    $vhubName = "vhub-$($subscription.primaryRegion)-001"
    
    # Resolve IPAM block to CIDR
    $vhubPrefix = Resolve-IpamBlock -BlockName $ipamConfig.block -Space $ipamConfig.space -SizeHint $ipamConfig.vnetCidrSizeHint
    
    # Get Log Analytics workspace ID (if available)
    $laWorkspaceId = $null
    $laWorkspaceName = "law-$subscriptionPurpose-$($subscription.primaryRegion)-001"
    $laRgName = "rg-$subscriptionPurpose-logging-$($subscription.primaryRegion)-001"
    
    try {
        $laWorkspaceId = (az monitor log-analytics workspace show `
            --resource-group $laRgName `
            --workspace-name $laWorkspaceName `
            --query id -o tsv 2>$null)
    }
    catch {
        Write-Log "Log Analytics workspace not found, continuing without it" -Level "WARN"
    }
    
    $connectivityParams = @{
        vwanName                  = $vwanName
        vhubName                  = $vhubName
        location                  = $subscription.primaryRegion
        tags                      = $subscription.tags
        vhubAddressPrefix         = $vhubPrefix
        enableFirewall            = $true
        firewallSku               = "Standard"
        enableVpnGateway          = $false
        logAnalyticsWorkspaceId   = $laWorkspaceId
    }
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy vwan-hub.bicep to RG $networkingRgName" -Level "WARN"
        Write-Log "Parameters: $($connectivityParams | ConvertTo-Json -Depth 3)" -Level "WARN"
    } else {
        try {
            Restore-BicepModules -BicepFile "../bicep/vwan-hub.bicep"
            
            $vwanParamArray = @(
                "vwanName=$vwanName",
                "vhubName=$vhubName",
                "location=$($connectivityParams.location)",
                "tags=$($connectivityParams.tags | ConvertTo-Json -Compress)",
                "vhubAddressPrefix=$vhubPrefix",
                "enableFirewall=$($connectivityParams.enableFirewall)",
                "firewallSku=$($connectivityParams.firewallSku)",
                "enableVpnGateway=$($connectivityParams.enableVpnGateway)"
            )
            
            if ($laWorkspaceId) {
                $vwanParamArray += "logAnalyticsWorkspaceId=$laWorkspaceId"
            }
            
            az deployment group create `
                --subscription $azSubscriptionId `
                --resource-group $networkingRgName `
                --name "vwan-$($subscription.aliasName)-$(Get-Date -Format 'yyyyMMddHHmmss')" `
                --template-file "../bicep/vwan-hub.bicep" `
                --parameters $vwanParamArray `
                --output json | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                throw "vWAN hub deployment failed with exit code $LASTEXITCODE"
            }
            
            Write-Log "vWAN hub deployed successfully" -Level "SUCCESS"
        }
        catch {
            Write-Log "Failed to deploy vWAN hub: $_" -Level "ERROR"
            exit 1
        }
    }
}

# =============================================================================
# Phase 3: Deploy Spoke vNet (for spoke/workload role)
# =============================================================================

elseif ($subscriptionRole -in @("spoke", "workload")) {
    Write-Log "Phase 2: Deploying spoke vNet" -Level "SUCCESS"
    
    # Load IPAM config
    $ipamConfig = Get-IpamConfig -AliasName $subscription.aliasName
    if (!$ipamConfig) {
        Write-Log "Spoke/workload subscription requires IPAM configuration for networking" -Level "WARN"
        Write-Log "Skipping spoke vNet deployment. Add entry for '$($subscription.aliasName)' in config/ipam.json" -Level "WARN"
        exit 0
    }
    
    Write-Log "Deploying spoke vNet for region $($subscription.primaryRegion)"
    
    $vnetName = "vnet-$subscriptionPurpose-$($subscription.primaryRegion)-001"
    
    # Resolve IPAM block to CIDR
    $vnetPrefix = Resolve-IpamBlock -BlockName $ipamConfig.block -Space $ipamConfig.space -SizeHint $ipamConfig.vnetCidrSizeHint
    
    # Get hub resource ID
    $hubResourceId = $null
    if ($HubSubscriptionId -and $HubResourceGroup -and $HubName) {
        $normalizedHubSubId = Normalize-SubscriptionId -SubscriptionId $HubSubscriptionId
        $hubResourceId = Get-HubResourceId -SubscriptionId $normalizedHubSubId -ResourceGroup $HubResourceGroup -HubName $HubName
    } else {
        # Try to find hub from platform-connectivity subscription
        Write-Log "Hub parameters not provided, attempting to find hub from platform-connectivity subscription" -Level "INFO"
        $hubSub = $config.subscriptions | Where-Object { $_.role -eq "hub" -and $_.primaryRegion -eq $subscription.primaryRegion } | Select-Object -First 1
        if ($hubSub) {
            $hubSubId = (az account subscription alias show --name $hubSub.aliasName --query "properties.subscriptionId" -o tsv 2>$null)
            $hubSubId = Normalize-SubscriptionId -SubscriptionId $hubSubId
            
            if ($hubSubId) {
                $hubRgName = "rg-network-core-network-$($subscription.primaryRegion)-001"
                $hubVhubName = "vhub-$($subscription.primaryRegion)-001"
                $hubResourceId = Get-HubResourceId -SubscriptionId $hubSubId -ResourceGroup $hubRgName -HubName $hubVhubName
            }
        }
    }
    
    if (!$hubResourceId) {
        Write-Log "Could not determine hub resource ID. Spoke vNet will be created without hub connection." -Level "WARN"
        Write-Log "You can connect it later or provide -HubSubscriptionId, -HubResourceGroup, and -HubName parameters" -Level "WARN"
    }
    
    # Get Log Analytics workspace ID (if available)
    $laWorkspaceId = $null
    $laWorkspaceName = "law-$subscriptionPurpose-$($subscription.primaryRegion)-001"
    $laRgName = "rg-$subscriptionPurpose-logging-$($subscription.primaryRegion)-001"
    
    try {
        $laWorkspaceId = (az monitor log-analytics workspace show `
            --resource-group $laRgName `
            --workspace-name $laWorkspaceName `
            --query id -o tsv 2>$null)
    }
    catch {
        Write-Log "Log Analytics workspace not found, continuing without it" -Level "WARN"
    }
    
    $spokeParams = @{
        vnetName                 = $vnetName
        location                 = $subscription.primaryRegion
        tags                     = $subscription.tags
        addressPrefixes          = @($vnetPrefix)
        subnets                  = @()
        virtualHubResourceId     = $hubResourceId
        enableInternetSecurity   = $true
        logAnalyticsWorkspaceId  = $laWorkspaceId
    }
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy spoke-vnet.bicep to RG $networkingRgName" -Level "WARN"
        Write-Log "Parameters: $($spokeParams | ConvertTo-Json -Depth 3)" -Level "WARN"
    } else {
        try {
            Restore-BicepModules -BicepFile "../bicep/spoke-vnet.bicep"
            
            $spokeParamArray = @(
                "vnetName=$vnetName",
                "location=$($spokeParams.location)",
                "tags=$($spokeParams.tags | ConvertTo-Json -Compress)",
                "addressPrefixes=$($spokeParams.addressPrefixes | ConvertTo-Json -Compress)",
                "subnets=$($spokeParams.subnets | ConvertTo-Json -Compress)",
                "enableInternetSecurity=$($spokeParams.enableInternetSecurity)"
            )
            
            if ($hubResourceId) {
                $spokeParamArray += "virtualHubResourceId=$hubResourceId"
            }
            
            if ($laWorkspaceId) {
                $spokeParamArray += "logAnalyticsWorkspaceId=$laWorkspaceId"
            }
            
            az deployment group create `
                --subscription $azSubscriptionId `
                --resource-group $networkingRgName `
                --name "spoke-$($subscription.aliasName)-$(Get-Date -Format 'yyyyMMddHHmmss')" `
                --template-file "../bicep/spoke-vnet.bicep" `
                --parameters $spokeParamArray `
                --output json | Out-Null
            
            if ($LASTEXITCODE -ne 0) {
                throw "Spoke vNet deployment failed with exit code $LASTEXITCODE"
            }
            
            Write-Log "Spoke vNet deployed successfully" -Level "SUCCESS"
        }
        catch {
            Write-Log "Failed to deploy spoke vNet: $_" -Level "ERROR"
            exit 1
        }
    }
}

# =============================================================================
# Summary
# =============================================================================

Write-Log "Connectivity deployment completed successfully" -Level "SUCCESS"
Write-Log "Subscription: $($subscription.displayName)"
Write-Log "Azure Sub ID: $azSubscriptionId"
Write-Log "Networking RG: $networkingRgName"
Write-Log ""
Write-Log "Next steps:"
Write-Log "1. Configure firewall rules (for hub deployments)"
Write-Log "2. Set up VPN connections (if needed)"
Write-Log "3. Verify hub-spoke connectivity"

