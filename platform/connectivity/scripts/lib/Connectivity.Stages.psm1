#Requires -Version 7.0
<#
.SYNOPSIS
    Stage deployment functions for connectivity infrastructure
#>

$modulePath = $PSScriptRoot
$scriptsDir = Split-Path $modulePath -Parent
$connectivityDir = Split-Path $scriptsDir -Parent
$bicepDir = Join-Path $connectivityDir "bicep"
Import-Module (Join-Path $modulePath "Connectivity.Common.psm1") -Force
Import-Module (Join-Path $modulePath "Connectivity.Azure.psm1") -Force

function Deploy-HubCore {
    <#
    .SYNOPSIS
        Deploys Hub Core (vWAN + vHub)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$Location,
        
        [Parameter(Mandatory)]
        [object]$Tags,
        
        [Parameter(Mandatory)]
        [string]$VwanName,
        
        [Parameter(Mandatory)]
        [string]$VhubName,
        
        [Parameter(Mandatory)]
        [string]$VhubAddressPrefix,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableVpnGateway = $false,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionAlias,
        
        [Parameter(Mandatory = $false)]
        [string]$DeploymentSuffix,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy hub-core.bicep to RG $ResourceGroup" -Level "WARN"
        return @{
            virtualWanResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualWans/$VwanName"
            virtualHubResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualHubs/$VhubName"
        }
    }
    
    try {
        Write-Log "Phase A: Deploying Hub Core (vWAN + vHub)..." -Level "INFO"
        $bicepFile = Join-Path $bicepDir "hub-core.bicep"
        Restore-BicepModules -BicepFile $bicepFile
        
        $hubCoreParamArray = @(
            "environment=prod",
            "location=$Location",
            "tags=$($Tags | ConvertTo-Json -Compress)",
            "vwanName=$VwanName",
            "vhubName=$VhubName",
            "vhubAddressPrefix=$VhubAddressPrefix",
            "enableVpnGateway=$EnableVpnGateway"
        )
        
        if ($DeploymentSuffix) {
            $hubCoreParamArray += "deploymentSuffix=$DeploymentSuffix"
        }
        
        $hubCoreDeploymentName = "hub-core-$SubscriptionAlias-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        $azOutput = az deployment group create `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $hubCoreDeploymentName `
            --template-file $bicepFile `
            --parameters $hubCoreParamArray `
            --only-show-errors `
            -o json 2>&1
        
        $azText = ($azOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($azText)) {
            $azText = "(no output captured from Azure CLI)"
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Azure CLI deployment failed with exit code: $LASTEXITCODE" -Level "ERROR"
            Write-Log "Azure CLI output:" -Level "ERROR"
            Write-Log $azText -Level "ERROR"
            throw "Hub Core deployment failed. Azure CLI returned exit code $LASTEXITCODE. See error output above."
        }
        
        if ([string]::IsNullOrWhiteSpace($azText) -or $azText -eq "(no output captured from Azure CLI)") {
            throw "Hub Core deployment failed. Azure CLI returned no JSON output."
        }
        
        $hubCoreResult = $azText | ConvertFrom-Json
        
        Write-Log "Hub Core deployed successfully" -Level "SUCCESS"
        
        return @{
            virtualWanResourceId = $hubCoreResult.properties.outputs.virtualWanResourceId.value
            virtualHubResourceId = $hubCoreResult.properties.outputs.virtualHubResourceId.value
        }
    }
    catch {
        Write-Log "Failed to deploy Hub Core: $_" -Level "ERROR"
        throw
    }
}

function Deploy-FirewallPolicy {
    <#
    .SYNOPSIS
        Deploys Azure Firewall Policy
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$Location,
        
        [Parameter(Mandatory)]
        [object]$Tags,
        
        [Parameter(Mandatory)]
        [string]$FirewallPolicyName,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy firewall-policy.bicep to RG $ResourceGroup" -Level "WARN"
        return @{
            firewallPolicyResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/firewallPolicies/$FirewallPolicyName"
        }
    }
    
    try {
        Write-Log "Phase B.1: Deploying Firewall Policy..." -Level "INFO"
        $bicepFile = Join-Path $bicepDir "firewall-policy.bicep"
        Restore-BicepModules -BicepFile $bicepFile
        
        $fwPolicyDeploymentName = "fwpolicy-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        $fwPolicyParams = @(
            "environment=prod",
            "location=$Location",
            "tags=$($Tags | ConvertTo-Json -Compress)",
            "firewallPolicyName=$FirewallPolicyName",
            "policyTier=Standard",
            "threatIntelMode=Alert",
            "enableDnsProxy=false"
        )
        
        Invoke-WithRetry {
            $azOutput = az deployment group create `
                --subscription $SubscriptionId `
                --resource-group $ResourceGroup `
                --name $fwPolicyDeploymentName `
                --template-file $bicepFile `
                --parameters $fwPolicyParams `
                --only-show-errors `
                -o json 2>&1
            
            $azText = ($azOutput | Out-String).Trim()
            if ([string]::IsNullOrWhiteSpace($azText)) {
                $azText = "(no output captured from Azure CLI)"
            }
            
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Azure CLI deployment failed with exit code: $LASTEXITCODE" -Level "ERROR"
                Write-Log "Azure CLI output:" -Level "ERROR"
                Write-Log $azText -Level "ERROR"
                throw "Firewall policy deployment failed. Azure CLI returned exit code $LASTEXITCODE. See error output above."
            }
        }
        
        $fwPolicyOutputs = az deployment group show `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $fwPolicyDeploymentName `
            --query "properties.outputs" -o json | ConvertFrom-Json
        
        $firewallPolicyId = $fwPolicyOutputs.firewallPolicyResourceId.value
        Write-Log "Firewall Policy deployed successfully: $firewallPolicyId" -Level "SUCCESS"
        
        return @{
            firewallPolicyResourceId = $firewallPolicyId
        }
    }
    catch {
        Write-Log "Failed to deploy Firewall Policy: $_" -Level "ERROR"
        throw
    }
}

function Deploy-Firewall {
    <#
    .SYNOPSIS
        Deploys Azure Firewall attached to Virtual Hub
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$Location,
        
        [Parameter(Mandatory)]
        [object]$Tags,
        
        [Parameter(Mandatory)]
        [string]$VirtualHubResourceId,
        
        [Parameter(Mandatory)]
        [string]$VhubName,
        
        [Parameter(Mandatory)]
        [string]$FirewallPolicyResourceId,
        
        [Parameter(Mandatory = $false)]
        [string]$FirewallSku = "Standard",
        
        [Parameter(Mandatory)]
        [string]$SubscriptionAlias,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy firewall.bicep to RG $ResourceGroup" -Level "WARN"
        return @{
            azureFirewallResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/azureFirewalls/fw-$VhubName"
        }
    }
    
    try {
        Write-Log "Phase B: Deploying Azure Firewall..." -Level "INFO"
        $bicepFile = Join-Path $bicepDir "firewall.bicep"
        Restore-BicepModules -BicepFile $bicepFile
        
        $firewallParamArray = @(
            "environment=prod",
            "location=$Location",
            "tags=$($Tags | ConvertTo-Json -Compress)",
            "virtualHubResourceId=$VirtualHubResourceId",
            "vhubName=$VhubName",
            "firewallPolicyResourceId=$FirewallPolicyResourceId",
            "firewallSku=$FirewallSku"
        )
        
        $firewallDeploymentName = "firewall-$SubscriptionAlias-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        $azOutput = az deployment group create `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $firewallDeploymentName `
            --template-file $bicepFile `
            --parameters $firewallParamArray `
            --only-show-errors `
            -o json 2>&1
        
        $azText = ($azOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($azText)) {
            $azText = "(no output captured from Azure CLI)"
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Azure CLI deployment failed with exit code: $LASTEXITCODE" -Level "ERROR"
            Write-Log "Azure CLI output:" -Level "ERROR"
            Write-Log $azText -Level "ERROR"
            throw "Firewall deployment failed. Azure CLI returned exit code $LASTEXITCODE. See error output above."
        }
        
        if ([string]::IsNullOrWhiteSpace($azText) -or $azText -eq "(no output captured from Azure CLI)") {
            throw "Firewall deployment failed. Azure CLI returned no JSON output."
        }
        
        $firewallResult = $azText | ConvertFrom-Json
        
        Write-Log "Azure Firewall deployed successfully" -Level "SUCCESS"
        
        return @{
            azureFirewallResourceId = $firewallResult.properties.outputs.azureFirewallResourceId.value
        }
    }
    catch {
        Write-Log "Failed to deploy Azure Firewall: $_" -Level "ERROR"
        throw
    }
}

function Deploy-Routing {
    <#
    .SYNOPSIS
        Deploys Routing Intent for forced egress through Azure Firewall
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$VirtualHubResourceId,
        
        [Parameter(Mandatory)]
        [string]$AzureFirewallResourceId,
        
        [Parameter(Mandatory)]
        [string]$VhubName,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('RoutingIntent', 'CustomRouteTables')]
        [string]$RoutingMode = 'RoutingIntent',
        
        [Parameter(Mandatory)]
        [string]$SubscriptionAlias,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    if ($RoutingMode -eq 'RoutingIntent') {
        Write-Log "Verifying no custom route tables exist (Routing Intent requirement)..." -Level "INFO"
        $existingRouteTables = az network vhub route-table list `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --vhub-name $VhubName `
            -o json 2>$null | ConvertFrom-Json
        
        if ($existingRouteTables) {
            $customRouteTables = $existingRouteTables | Where-Object { 
                $_.Name -ne 'defaultRouteTable' -and $_.Name -ne 'noneRouteTable' 
            }
            
            if ($customRouteTables) {
                Write-Log "ERROR: Custom route tables found: $($customRouteTables.Name -join ', ')" -Level "ERROR"
                Write-Log "Routing Intent and custom route tables are mutually exclusive." -Level "ERROR"
                Write-Log "Delete custom route tables first, or use -RoutingMode 'CustomRouteTables' (not yet implemented)" -Level "ERROR"
                throw "Custom route tables exist - cannot deploy Routing Intent"
            }
        }
    }
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy route-intent.bicep to RG $ResourceGroup" -Level "WARN"
        return @{
            routingIntentResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualHubs/$VhubName/routingIntent/default"
        }
    }
    
    try {
        Write-Log "Phase C: Deploying Routing Intent..." -Level "INFO"
        $bicepFile = Join-Path $bicepDir "route-intent.bicep"
        Restore-BicepModules -BicepFile $bicepFile
        
        $routingParamArray = @(
            "virtualHubResourceId=$VirtualHubResourceId",
            "azureFirewallResourceId=$AzureFirewallResourceId"
        )
        
        $routingDeploymentName = "routing-intent-$SubscriptionAlias-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        $azOutput = az deployment group create `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $routingDeploymentName `
            --template-file $bicepFile `
            --parameters $routingParamArray `
            --only-show-errors `
            -o json 2>&1
        
        $azText = ($azOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($azText)) {
            $azText = "(no output captured from Azure CLI)"
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Azure CLI deployment failed with exit code: $LASTEXITCODE" -Level "ERROR"
            Write-Log "Azure CLI output:" -Level "ERROR"
            Write-Log $azText -Level "ERROR"
            throw "Routing Intent deployment failed. Azure CLI returned exit code $LASTEXITCODE. See error output above."
        }
        
        if ([string]::IsNullOrWhiteSpace($azText) -or $azText -eq "(no output captured from Azure CLI)") {
            throw "Routing Intent deployment failed. Azure CLI returned no JSON output."
        }
        
        $routingResult = $azText | ConvertFrom-Json
        
        Write-Log "Routing Intent deployed successfully" -Level "SUCCESS"
        
        return @{
            routingIntentResourceId = $routingResult.properties.outputs.routingIntentResourceId.value
        }
    }
    catch {
        Write-Log "Failed to deploy Routing Intent: $_" -Level "ERROR"
        throw
    }
}

function Deploy-PrivateDns {
    <#
    .SYNOPSIS
        Deploys Private DNS Zones
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$Location,
        
        [Parameter(Mandatory)]
        [object]$Tags,
        
        [Parameter(Mandatory)]
        [array]$ZoneKeys,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionAlias,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    if (!$ZoneKeys -or $ZoneKeys.Count -eq 0) {
        Write-Log "No Private DNS zones configured, skipping DNS zone deployment" -Level "WARN"
        return @{
            privateDnsZoneResourceIds = @{}
        }
    }
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy private-dns-zones.bicep to RG $ResourceGroup" -Level "WARN"
        return @{
            privateDnsZoneResourceIds = @{}
        }
    }
    
    try {
        Write-Log "Phase D: Deploying Private DNS Zones" -Level "SUCCESS"
        Write-Log "Deploying Private DNS zones: $($ZoneKeys -join ', ')" -Level "INFO"
        
        $zoneConfigs = @()
        foreach ($zoneKey in $ZoneKeys) {
            $zoneConfigs += @{ key = $zoneKey }
        }
        
        $bicepFile = Join-Path $bicepDir "private-dns-zones.bicep"
        Restore-BicepModules -BicepFile $bicepFile
        
        $dnsParamArray = @(
            "environment=prod",
            "location=$Location",
            "tags=$($Tags | ConvertTo-Json -Compress)",
            "privateDnsZoneConfigs=$($zoneConfigs | ConvertTo-Json -Compress)"
        )
        
        $dnsDeploymentName = "dns-zones-$SubscriptionAlias-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        $azOutput = az deployment group create `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $dnsDeploymentName `
            --template-file $bicepFile `
            --parameters $dnsParamArray `
            --only-show-errors `
            -o json 2>&1
        
        $azText = ($azOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($azText)) {
            $azText = "(no output captured from Azure CLI)"
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Azure CLI deployment failed with exit code: $LASTEXITCODE" -Level "ERROR"
            Write-Log "Azure CLI output:" -Level "ERROR"
            Write-Log $azText -Level "ERROR"
            throw "Private DNS zones deployment failed. Azure CLI returned exit code $LASTEXITCODE. See error output above."
        }
        
        if ([string]::IsNullOrWhiteSpace($azText) -or $azText -eq "(no output captured from Azure CLI)") {
            throw "Private DNS zones deployment failed. Azure CLI returned no JSON output."
        }
        
        Write-Log "Private DNS zones deployed successfully" -Level "SUCCESS"
        
        $dnsOutputs = az deployment group show `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $dnsDeploymentName `
            --query "properties.outputs" -o json | ConvertFrom-Json
        
        $zoneResourceIds = @{}
        if ($dnsOutputs.privateDnsZoneResourceIds) {
            Write-Log "Deployed Private DNS zones:" -Level "SUCCESS"
            $dnsOutputs.privateDnsZoneResourceIds.PSObject.Properties | ForEach-Object {
                $zoneResourceIds[$_.Name] = $_.Value.value
                Write-Log "  - $($_.Name): $($_.Value.value)" -Level "SUCCESS"
            }
        }
        
        return @{
            privateDnsZoneResourceIds = $zoneResourceIds
        }
    }
    catch {
        Write-Log "Failed to deploy Private DNS zones: $_" -Level "ERROR"
        Write-Log "Continuing with other deployments..." -Level "WARN"
        return @{
            privateDnsZoneResourceIds = @{}
        }
    }
}

function Deploy-VwanHub {
    <#
    .SYNOPSIS
        Deploys vWAN Hub using the backward-compatible orchestrator template
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$Location,
        
        [Parameter(Mandatory)]
        [object]$Tags,
        
        [Parameter(Mandatory)]
        [string]$VwanName,
        
        [Parameter(Mandatory)]
        [string]$VhubName,
        
        [Parameter(Mandatory)]
        [string]$VhubAddressPrefix,
        
        [Parameter(Mandatory)]
        [string]$FirewallPolicyResourceId,
        
        [Parameter(Mandatory = $false)]
        [string]$LogAnalyticsWorkspaceResourceId,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionAlias,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy vwan-hub.bicep to RG $ResourceGroup" -Level "WARN"
        return @{
            virtualWanResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualWans/$VwanName"
            virtualHubResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualHubs/$VhubName"
            azureFirewallResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/azureFirewalls/fw-$VhubName"
            routingIntentResourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Network/virtualHubs/$VhubName/routingIntent/default"
        }
    }
    
    try {
        Write-Log "Phase 2.2: Deploying vWAN Hub (using vwan-hub.bicep orchestrator)..." -Level "INFO"
        $bicepFile = Join-Path $bicepDir "vwan-hub.bicep"
        Restore-BicepModules -BicepFile $bicepFile
        
        $vwanParamArray = @(
            "environment=prod",
            "vwanName=$VwanName",
            "vhubName=$VhubName",
            "location=$Location",
            "tags=$($Tags | ConvertTo-Json -Compress)",
            "vhubAddressPrefix=$VhubAddressPrefix",
            "enableFirewall=true",
            "firewallSku=Standard",
            "enableVpnGateway=false",
            "firewallPolicyResourceId=$FirewallPolicyResourceId"
        )
        
        if ($LogAnalyticsWorkspaceResourceId) {
            $vwanParamArray += "logAnalyticsWorkspaceResourceId=$LogAnalyticsWorkspaceResourceId"
        }
        
        $vwanDeploymentName = "vwan-$SubscriptionAlias-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        $azOutput = az deployment group create `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $vwanDeploymentName `
            --template-file $bicepFile `
            --parameters $vwanParamArray `
            --only-show-errors `
            -o json 2>&1
        
        $azText = ($azOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($azText)) {
            $azText = "(no output captured from Azure CLI)"
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Azure CLI deployment failed with exit code: $LASTEXITCODE" -Level "ERROR"
            Write-Log "Azure CLI output:" -Level "ERROR"
            Write-Log $azText -Level "ERROR"
            throw "vWAN hub deployment failed. Azure CLI returned exit code $LASTEXITCODE. See error output above."
        }
        
        if ([string]::IsNullOrWhiteSpace($azText) -or $azText -eq "(no output captured from Azure CLI)") {
            throw "vWAN hub deployment failed. Azure CLI returned no JSON output."
        }
        
        $hubResult = $azText | ConvertFrom-Json
        
        Write-Log "vWAN hub deployed successfully" -Level "SUCCESS"
        
        return @{
            virtualWanResourceId = $hubResult.properties.outputs.virtualWanResourceId.value
            virtualHubResourceId = $hubResult.properties.outputs.virtualHubResourceId.value
            azureFirewallResourceId = $hubResult.properties.outputs.azureFirewallResourceId.value
            routingIntentResourceId = $hubResult.properties.outputs.routingIntentResourceId.value
        }
    }
    catch {
        Write-Log "Failed to deploy vWAN hub: $_" -Level "ERROR"
        throw
    }
}

function Deploy-SpokeVnet {
    <#
    .SYNOPSIS
        Deploys a spoke VNet and optionally connects it to a Virtual Hub
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$Location,
        
        [Parameter(Mandatory)]
        [object]$Tags,
        
        [Parameter(Mandatory)]
        [string]$VnetName,
        
        [Parameter(Mandatory)]
        [string]$VnetPrefix,
        
        [Parameter(Mandatory = $false)]
        [array]$Subnets = @(),
        
        [Parameter(Mandatory = $false)]
        [string]$VirtualHubResourceId,
        
        [Parameter(Mandatory = $false)]
        [string]$VirtualHubName,
        
        [Parameter(Mandatory = $false)]
        [string]$LogAnalyticsWorkspaceResourceId,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionAlias,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy spoke-vnet.bicep to RG $ResourceGroup" -Level "WARN"
        return
    }
    
    try {
        $bicepFile = Join-Path $bicepDir "spoke-vnet.bicep"
        Restore-BicepModules -BicepFile $bicepFile
        
        # Fail fast if no subnets defined - workload VNets require subnets
        if (-not $Subnets -or $Subnets.Count -eq 0) {
            throw "No subnets defined for spoke VNet '$VnetName'. Subnet blueprint is missing or invalid. A workload VNet requires at least one subnet. Check that subnet-blueprints.json exists and contains the blueprint key specified in ipam.json."
        }
        
        # Build parameters file for complex JSON objects (more reliable than inline parameters)
        $deploymentName = "spoke-$SubscriptionAlias-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        # Use temp directory - handle both Windows and Unix-like systems
        $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
        if ([string]::IsNullOrWhiteSpace($tempDir) -or !(Test-Path $tempDir)) {
            # Fallback to generated directory in connectivity scripts folder
            $scriptsDir = Split-Path $PSScriptRoot -Parent
            $connectivityDir = Split-Path $scriptsDir -Parent
            $tempDir = Join-Path $connectivityDir "scripts/generated"
            if (!(Test-Path $tempDir)) {
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            }
        }
        $paramFile = Join-Path $tempDir "spoke-$SubscriptionAlias-$deploymentName.parameters.json"
        
        $paramObject = @{
            '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
            contentVersion = "1.0.0.0"
            parameters = @{
                environment = @{ value = "prod" }
                vnetName = @{ value = $VnetName }
                location = @{ value = $Location }
                tags = @{ value = $Tags }
                addressPrefixes = @{ value = @($VnetPrefix) }
                subnets = @{ value = $Subnets }
                enableInternetSecurity = @{ value = $true }
            }
        }
        
        if ($VirtualHubResourceId) {
            $paramObject.parameters.virtualHubResourceId = @{ value = $VirtualHubResourceId }
            $paramObject.parameters.virtualHubName = @{ value = $VirtualHubName }
        }
        
        if ($LogAnalyticsWorkspaceResourceId) {
            $paramObject.parameters.logAnalyticsWorkspaceResourceId = @{ value = $LogAnalyticsWorkspaceResourceId }
        }
        
        # Write parameters file
        $paramObject | ConvertTo-Json -Depth 10 | Set-Content $paramFile -Force
        Write-Log "Created parameters file: $paramFile" -Level "INFO"
        
        Write-Log "Deploying spoke VNet: $VnetName" -Level "INFO"
        Write-Log "Deployment name: $deploymentName" -Level "INFO"
        Write-Log "Subscription: $SubscriptionId" -Level "INFO"
        Write-Log "Resource Group: $ResourceGroup" -Level "INFO"
        Write-Log "Bicep file: $bicepFile" -Level "INFO"
        
        # Capture Azure CLI output and stringify it
        $azOutput = az deployment group create `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $deploymentName `
            --template-file $bicepFile `
            --parameters "@$paramFile" `
            --only-show-errors `
            -o json 2>&1
        
        $azText = ($azOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($azText)) {
            $azText = "(no output captured from Azure CLI)"
        }
        
        # Check exit code FIRST - never parse JSON if Azure CLI failed
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Azure CLI deployment failed with exit code: $LASTEXITCODE" -Level "ERROR"
            Write-Log "Azure CLI output:" -Level "ERROR"
            Write-Log $azText -Level "ERROR"
            throw "Spoke vNet deployment failed. Azure CLI returned exit code $LASTEXITCODE. See error output above."
        }
        
        # Validate we got JSON output
        if ([string]::IsNullOrWhiteSpace($azText) -or $azText -eq "(no output captured from Azure CLI)") {
            throw "Spoke vNet deployment failed. Azure CLI returned no JSON output."
        }
        
        # Parse JSON only after confirming success
        try {
            $deployment = $azText | ConvertFrom-Json
            Write-Log "Spoke vNet deployed successfully" -Level "SUCCESS"
            Write-Log "Deployment ID: $($deployment.id)" -Level "INFO"
            
            # Return deployment result so caller can get VNet resource ID
            return @{
                DeploymentId = $deployment.id
                VnetResourceId = $deployment.properties.outputs.resourceId.value
            }
        }
        catch {
            Write-Log "Failed to parse deployment JSON output" -Level "ERROR"
            Write-Log "Raw output: $azText" -Level "ERROR"
            throw "Spoke vNet deployment may have succeeded but output parsing failed: $_"
        }
        finally {
            # Clean up temporary parameters file
            if (Test-Path $paramFile) {
                Remove-Item $paramFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Log "Failed to deploy spoke vNet: $_" -Level "ERROR"
        # Clean up temporary parameters file on error
        if (Test-Path $paramFile) {
            Remove-Item $paramFile -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Deploy-VnetConnection {
    <#
    .SYNOPSIS
        Deploys a Virtual Hub VNet connection (must be deployed to hub subscription)
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$Location,
        
        [Parameter(Mandatory)]
        [object]$Tags,
        
        [Parameter(Mandatory)]
        [string]$VirtualHubResourceId,
        
        [Parameter(Mandatory)]
        [string]$VirtualHubName,
        
        [Parameter(Mandatory)]
        [string]$RemoteVirtualNetworkResourceId,
        
        [Parameter(Mandatory = $false)]
        [string]$ConnectionName = '',
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableInternetSecurity = $true,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    if ($IsWhatIf) {
        Write-Log "WhatIf: Would deploy vnet-connection.bicep to hub RG $ResourceGroup" -Level "WARN"
        return
    }
    
    try {
        $bicepFile = Join-Path $bicepDir "vnet-connection.bicep"
        Restore-BicepModules -BicepFile $bicepFile
        
        # Build parameters file
        $deploymentName = "vnet-connection-$(Get-Date -Format 'yyyyMMddHHmmss')"
        $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { [System.IO.Path]::GetTempPath() }
        if ([string]::IsNullOrWhiteSpace($tempDir) -or !(Test-Path $tempDir)) {
            $scriptsDir = Split-Path $PSScriptRoot -Parent
            $connectivityDir = Split-Path $scriptsDir -Parent
            $tempDir = Join-Path $connectivityDir "scripts/generated"
            if (!(Test-Path $tempDir)) {
                New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
            }
        }
        $paramFile = Join-Path $tempDir "vnet-connection-$deploymentName.parameters.json"
        
        $paramObject = @{
            '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
            contentVersion = "1.0.0.0"
            parameters = @{
                environment = @{ value = "prod" }
                location = @{ value = $Location }
                tags = @{ value = $Tags }
                virtualHubResourceId = @{ value = $VirtualHubResourceId }
                virtualHubName = @{ value = $VirtualHubName }
                remoteVirtualNetworkResourceId = @{ value = $RemoteVirtualNetworkResourceId }
                connectionName = @{ value = $ConnectionName }
                enableInternetSecurity = @{ value = $EnableInternetSecurity }
            }
        }
        
        $paramObject | ConvertTo-Json -Depth 10 | Set-Content $paramFile -Force
        Write-Log "Created parameters file: $paramFile" -Level "INFO"
        
        Write-Log "Deploying hub connection: $ConnectionName" -Level "INFO"
        Write-Log "Deployment name: $deploymentName" -Level "INFO"
        Write-Log "Subscription: $SubscriptionId" -Level "INFO"
        Write-Log "Resource Group: $ResourceGroup" -Level "INFO"
        
        $azOutput = az deployment group create `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $deploymentName `
            --template-file $bicepFile `
            --parameters "@$paramFile" `
            --only-show-errors `
            -o json 2>&1
        
        $azText = ($azOutput | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($azText)) {
            $azText = "(no output captured from Azure CLI)"
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Azure CLI deployment failed with exit code: $LASTEXITCODE" -Level "ERROR"
            Write-Log "Azure CLI output:" -Level "ERROR"
            Write-Log $azText -Level "ERROR"
            throw "Hub connection deployment failed. Azure CLI returned exit code $LASTEXITCODE. See error output above."
        }
        
        if ([string]::IsNullOrWhiteSpace($azText) -or $azText -eq "(no output captured from Azure CLI)") {
            throw "Hub connection deployment failed. Azure CLI returned no JSON output."
        }
        
        try {
            $deployment = $azText | ConvertFrom-Json
            Write-Log "Hub connection deployed successfully" -Level "SUCCESS"
            Write-Log "Deployment ID: $($deployment.id)" -Level "INFO"
        }
        catch {
            Write-Log "Failed to parse deployment JSON output" -Level "ERROR"
            Write-Log "Raw output: $azText" -Level "ERROR"
            throw "Hub connection deployment may have succeeded but output parsing failed: $_"
        }
        finally {
            if (Test-Path $paramFile) {
                Remove-Item $paramFile -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Log "Failed to deploy hub connection: $_" -Level "ERROR"
        if (Test-Path $paramFile) {
            Remove-Item $paramFile -Force -ErrorAction SilentlyContinue
        }
        throw
    }
}

function Invoke-HubDeployment {
    <#
    .SYNOPSIS
        Orchestrates hub deployment with stage-based logic
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [object]$Subscription,
        
        [Parameter(Mandatory)]
        [object]$Config,
        
        [Parameter(Mandatory)]
        [bool]$DeployAll,
        
        [Parameter(Mandatory)]
        [bool]$DeployHubCore,
        
        [Parameter(Mandatory)]
        [bool]$DeployFirewallPolicy,
        
        [Parameter(Mandatory)]
        [bool]$DeployFirewall,
        
        [Parameter(Mandatory)]
        [bool]$DeployRouting,
        
        [Parameter(Mandatory)]
        [bool]$DeployPrivateDns,
        
        [Parameter(Mandatory)]
        [string]$RoutingMode,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    $ipamConfig = Get-IpamConfig -AliasName $subscription.aliasName
    if (!$ipamConfig) {
        Write-Log "Hub subscription requires IPAM configuration. Add entry for '$($subscription.aliasName)' in config/ipam.json" -Level "ERROR"
        throw "IPAM configuration missing"
    }
    
    # Generate unique deployment suffix for this run (prevents nested module name conflicts)
    $deploymentSuffix = Get-Date -Format 'yyyyMMddHHmmss'
    
    $vwanName = "vwan-$($subscription.primaryRegion)"
    $vhubName = "vhub-$($subscription.primaryRegion)-001"
    $vhubPrefix = Resolve-IpamBlock -BlockName $ipamConfig.block -Space $ipamConfig.space -SizeHint $ipamConfig.vnetCidrSizeHint
    $laWorkspaceId = Get-LogAnalyticsWorkspaceId -Config $config
    
    if (!$laWorkspaceId) {
        Write-Log "WARNING: Central Log Analytics workspace not found. Diagnostics will not be configured in Bicep." -Level "WARN"
    }
    
    $firewallPolicyId = $null
    $firewallPolicyName = "fwpolicy-$vhubName"
    
    if ($DeployFirewallPolicy) {
        $fwPolicyResult = Deploy-FirewallPolicy `
            -SubscriptionId $SubscriptionId `
            -ResourceGroup $ResourceGroup `
            -Location $subscription.primaryRegion `
            -Tags $subscription.tags `
            -FirewallPolicyName $firewallPolicyName `
            -IsWhatIf $IsWhatIf
        if ($fwPolicyResult) {
            $firewallPolicyId = $fwPolicyResult.firewallPolicyResourceId
        }
    } else {
        if ($DeployFirewall) {
            $existingPolicy = az network firewall policy show `
                --subscription $SubscriptionId `
                --resource-group $ResourceGroup `
                --name $firewallPolicyName `
                --query "id" -o tsv 2>$null
            if ($existingPolicy) {
                $firewallPolicyId = $existingPolicy
            } else {
                throw "Firewall Policy not found. Deploy Firewall Policy first using -DeployFirewallPolicy"
            }
        }
    }
    
    $virtualWanResourceId = $null
    $virtualHubResourceId = $null
    $azureFirewallResourceId = $null
    $routingIntentResourceId = $null
    
    if ($DeployAll) {
        if (!$firewallPolicyId) {
            throw "Firewall Policy ID is required for vWAN hub deployment"
        }
        
        $hubResult = Deploy-VwanHub `
            -SubscriptionId $SubscriptionId `
            -ResourceGroup $ResourceGroup `
            -Location $subscription.primaryRegion `
            -Tags $subscription.tags `
            -VwanName $vwanName `
            -VhubName $vhubName `
            -VhubAddressPrefix $vhubPrefix `
            -FirewallPolicyResourceId $firewallPolicyId `
            -LogAnalyticsWorkspaceResourceId $laWorkspaceId `
            -SubscriptionAlias $subscription.aliasName `
            -IsWhatIf $IsWhatIf
        
        if ($hubResult) {
            $virtualWanResourceId = $hubResult.virtualWanResourceId
            $virtualHubResourceId = $hubResult.virtualHubResourceId
            $azureFirewallResourceId = $hubResult.azureFirewallResourceId
            $routingIntentResourceId = $hubResult.routingIntentResourceId
        }
    } else {
        if ($DeployHubCore) {
            $hubCoreResult = Deploy-HubCore `
                -SubscriptionId $SubscriptionId `
                -ResourceGroup $ResourceGroup `
                -Location $subscription.primaryRegion `
                -Tags $subscription.tags `
                -VwanName $vwanName `
                -VhubName $vhubName `
                -VhubAddressPrefix $vhubPrefix `
                -EnableVpnGateway $false `
                -DeploymentSuffix $deploymentSuffix `
                -SubscriptionAlias $subscription.aliasName `
                -IsWhatIf $IsWhatIf
            
            if ($hubCoreResult) {
                $virtualWanResourceId = $hubCoreResult.virtualWanResourceId
                $virtualHubResourceId = $hubCoreResult.virtualHubResourceId
            }
        } else {
            $virtualWanResourceId = Get-ExistingResourceId -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroup -ResourceType "Microsoft.Network/virtualWans" -ResourceName $vwanName
            $virtualHubResourceId = Get-ExistingResourceId -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroup -ResourceType "Microsoft.Network/virtualHubs" -ResourceName $vhubName
            
            if (!$virtualHubResourceId) {
                throw "Virtual Hub not found. Hub Core is required but not deployed."
            }
        }
        
        if ($DeployFirewall) {
            if (!$virtualHubResourceId) {
                throw "Virtual Hub ID is required for Firewall deployment."
            }
            if (!$firewallPolicyId) {
                throw "Firewall Policy ID is required for Firewall deployment."
            }
            
            $firewallResult = Deploy-Firewall `
                -SubscriptionId $SubscriptionId `
                -ResourceGroup $ResourceGroup `
                -Location $subscription.primaryRegion `
                -Tags $subscription.tags `
                -VirtualHubResourceId $virtualHubResourceId `
                -VhubName $vhubName `
                -FirewallPolicyResourceId $firewallPolicyId `
                -FirewallSku "Standard" `
                -SubscriptionAlias $subscription.aliasName `
                -IsWhatIf $IsWhatIf
            
            if ($firewallResult) {
                $azureFirewallResourceId = $firewallResult.azureFirewallResourceId
            }
        } else {
            if ($DeployRouting) {
                $firewallName = "fw-$vhubName"
                $azureFirewallResourceId = Get-ExistingResourceId -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroup -ResourceType "Microsoft.Network/azureFirewalls" -ResourceName $firewallName
                if (!$azureFirewallResourceId) {
                    throw "Azure Firewall not found. Firewall is required for Routing Intent deployment."
                }
            }
        }
        
        if ($DeployRouting) {
            if (!$virtualHubResourceId) {
                throw "Virtual Hub ID is required for Routing Intent deployment."
            }
            if (!$azureFirewallResourceId) {
                throw "Azure Firewall ID is required for Routing Intent deployment."
            }
            
            $routingResult = Deploy-Routing `
                -SubscriptionId $SubscriptionId `
                -ResourceGroup $ResourceGroup `
                -VirtualHubResourceId $virtualHubResourceId `
                -AzureFirewallResourceId $azureFirewallResourceId `
                -VhubName $vhubName `
                -RoutingMode $RoutingMode `
                -SubscriptionAlias $subscription.aliasName `
                -IsWhatIf $IsWhatIf
            
            if ($routingResult) {
                $routingIntentResourceId = $routingResult.routingIntentResourceId
            }
        }
    }
    
    if ($laWorkspaceId -and !$IsWhatIf) {
        Write-Log "Phase 2.3: Configuring diagnostic settings (vWAN, vHub, Firewall)..." -Level "INFO"
        
        if ($virtualWanResourceId) {
            Ensure-DiagnosticSettings `
                -TargetResourceId $virtualWanResourceId `
                -LogAnalyticsWorkspaceResourceId $laWorkspaceId `
                -DiagnosticSettingName "diag-vwan"
        }
        
        if ($virtualHubResourceId) {
            Ensure-DiagnosticSettings `
                -TargetResourceId $virtualHubResourceId `
                -LogAnalyticsWorkspaceResourceId $laWorkspaceId `
                -DiagnosticSettingName "diag-vhub"
        }
        
        if ($azureFirewallResourceId) {
            Ensure-DiagnosticSettings `
                -TargetResourceId $azureFirewallResourceId `
                -LogAnalyticsWorkspaceResourceId $laWorkspaceId `
                -DiagnosticSettingName "diag-azfw"
        }
    }
    
    if ($DeployPrivateDns) {
        $connectivityConfig = Get-ConnectivityConfig
        if ($connectivityConfig -and $connectivityConfig.enablePrivateDns -eq $true) {
            $zoneKeys = $connectivityConfig.privateDnsZones
            try {
                Deploy-PrivateDns `
                    -SubscriptionId $SubscriptionId `
                    -ResourceGroup $ResourceGroup `
                    -Location $subscription.primaryRegion `
                    -Tags $subscription.tags `
                    -ZoneKeys $zoneKeys `
                    -SubscriptionAlias $subscription.aliasName `
                    -IsWhatIf $IsWhatIf | Out-Null
            }
            catch {
                Write-Log "Private DNS deployment failed (non-blocking): $_" -Level "WARN"
            }
        }
    }
}

function Invoke-SpokeDeployment {
    <#
    .SYNOPSIS
        Orchestrates spoke VNet deployment
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [object]$Subscription,
        
        [Parameter(Mandatory)]
        [object]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$HubSubscriptionId,
        
        [Parameter(Mandatory = $false)]
        [string]$HubResourceGroup,
        
        [Parameter(Mandatory = $false)]
        [string]$HubName,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionPurpose,
        
        [Parameter(Mandatory = $false)]
        [bool]$IsWhatIf = $false
    )
    
    $ipamConfig = Get-IpamConfig -AliasName $subscription.aliasName
    if (!$ipamConfig) {
        Write-Log "Spoke/workload subscription requires IPAM configuration for networking" -Level "WARN"
        Write-Log "Skipping spoke vNet deployment. Add entry for '$($subscription.aliasName)' in config/ipam.json" -Level "WARN"
        return
    }
    
    $vnetName = "vnet-$SubscriptionPurpose-$($subscription.primaryRegion)-001"
    $allocationKey = "$($subscription.aliasName)-workload"
    
    $vnetPrefix = Invoke-IpamAllocation `
        -AllocationKey $allocationKey `
        -CidrSize $ipamConfig.vnetCidrSizeHint `
        -SubscriptionAlias $subscription.aliasName
    
    if (!$vnetPrefix) {
        Write-Log "IPAM allocation failed, falling back to legacy resolution" -Level "WARN"
        $vnetPrefix = Resolve-IpamBlock -BlockName $ipamConfig.block -Space $ipamConfig.space -SizeHint $ipamConfig.vnetCidrSizeHint
    }
    
    if (!$vnetPrefix) {
        throw "Could not determine VNet CIDR prefix"
    }
    
    $subnets = @()
    if ($ipamConfig.subnetBlueprintKey) {
        $blueprint = Get-SubnetBlueprint -BlueprintKey $ipamConfig.subnetBlueprintKey
        if ($blueprint) {
            $subnets = Generate-Subnets -VnetCidr $vnetPrefix -Blueprint $blueprint
        }
    }
    
    $hubResourceId = $null
    if ($HubSubscriptionId -and $HubResourceGroup -and $HubName) {
        $normalizedHubSubId = Normalize-SubscriptionId -SubscriptionId $HubSubscriptionId
        $hubResourceId = Get-HubResourceId -SubscriptionId $normalizedHubSubId -ResourceGroup $HubResourceGroup -HubName $HubName
        if (!$hubResourceId) {
            Write-Log "WARNING: Could not find hub '$HubName' in resource group '$HubResourceGroup'. Hub connection will not be created." -Level "WARN"
        }
    } else {
        $hubSub = $config.subscriptions | Where-Object { $_.role -eq "hub" -and $_.primaryRegion -eq $subscription.primaryRegion } | Select-Object -First 1
        if ($hubSub) {
            $hubSubId = Resolve-SubscriptionIdFromAlias -AliasName $hubSub.aliasName
            if ($hubSubId) {
                $hubRgName = "rg-core-network-$($subscription.primaryRegion)-001"
                $hubVhubName = "vhub-$($subscription.primaryRegion)-001"
                Write-Log "Looking for hub: $hubVhubName in subscription $hubSubId, resource group $hubRgName" -Level "INFO"
                $hubResourceId = Get-HubResourceId -SubscriptionId $hubSubId -ResourceGroup $hubRgName -HubName $hubVhubName
                if (!$hubResourceId) {
                    Write-Log "WARNING: Could not find hub '$hubVhubName' in resource group '$hubRgName'. Hub connection will not be created." -Level "WARN"
                    Write-Log "The VNet will be deployed but not connected to the hub. You can connect it manually later." -Level "WARN"
                } else {
                    Write-Log "Found hub resource ID: $hubResourceId" -Level "INFO"
                }
            } else {
                Write-Log "WARNING: Could not resolve hub subscription ID from alias '$($hubSub.aliasName)'. Hub connection will not be created." -Level "WARN"
            }
        } else {
            Write-Log "WARNING: No hub subscription found for region '$($subscription.primaryRegion)'. Hub connection will not be created." -Level "WARN"
        }
    }
    
    $hubVhubName = "vhub-$($subscription.primaryRegion)-001"
    $laWorkspaceId = Get-LogAnalyticsWorkspaceId -Config $config
    
    # Deploy VNet WITHOUT hub connection (connection must be deployed to hub subscription)
    $vnetDeploymentResult = Deploy-SpokeVnet `
        -SubscriptionId $SubscriptionId `
        -ResourceGroup $ResourceGroup `
        -Location $subscription.primaryRegion `
        -Tags $subscription.tags `
        -VnetName $vnetName `
        -VnetPrefix $vnetPrefix `
        -Subnets $subnets `
        -VirtualHubResourceId $null `
        -VirtualHubName $null `
        -LogAnalyticsWorkspaceResourceId $laWorkspaceId `
        -SubscriptionAlias $subscription.aliasName `
        -IsWhatIf $IsWhatIf
    
    # Deploy hub connection separately to hub subscription (if hub was found)
    if ($hubResourceId -and $vnetDeploymentResult -and $vnetDeploymentResult.VnetResourceId) {
        Write-Log "Phase 3: Creating hub connection" -Level "SUCCESS"
        
        $vnetResourceId = $vnetDeploymentResult.VnetResourceId
        
        # Extract hub subscription ID and resource group from hub resource ID
        if ($hubResourceId -match '/subscriptions/([^/]+)/resourceGroups/([^/]+)/') {
            $hubSubId = $Matches[1]
            $hubRgName = $Matches[2]
            
            Write-Log "Deploying hub connection to hub subscription: $hubSubId" -Level "INFO"
            Write-Log "Hub resource group: $hubRgName" -Level "INFO"
            Write-Log "VNet resource ID: $vnetResourceId" -Level "INFO"
            
            Deploy-VnetConnection `
                -SubscriptionId $hubSubId `
                -ResourceGroup $hubRgName `
                -Location $subscription.primaryRegion `
                -Tags $subscription.tags `
                -VirtualHubResourceId $hubResourceId `
                -VirtualHubName $hubVhubName `
                -RemoteVirtualNetworkResourceId $vnetResourceId `
                -ConnectionName "$vnetName-connection" `
                -EnableInternetSecurity $true `
                -IsWhatIf $IsWhatIf
        } else {
            Write-Log "WARNING: Could not parse hub resource ID. Hub connection will not be created." -Level "WARN"
        }
    } elseif ($hubResourceId) {
        Write-Log "WARNING: VNet deployment did not return resource ID. Hub connection will not be created." -Level "WARN"
    }
}

Export-ModuleMember -Function Deploy-HubCore, Deploy-FirewallPolicy, Deploy-Firewall, `
    Deploy-Routing, Deploy-PrivateDns, Deploy-VwanHub, Deploy-SpokeVnet, Deploy-VnetConnection, `
    Invoke-HubDeployment, Invoke-SpokeDeployment
