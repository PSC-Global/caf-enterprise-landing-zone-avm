#Requires -Version 7.0
<#
.SYNOPSIS
    IPAM (IP Address Management) utility functions for connectivity deployments
#>

$modulePath = Join-Path $PSScriptRoot "Connectivity.Common.psm1"
if (Test-Path $modulePath) {
    Import-Module $modulePath -Force -ErrorAction SilentlyContinue
}

function Get-IpamConfig {
    <#
    .SYNOPSIS
        Loads IPAM configuration from JSON file for a subscription alias
    #>
    param(
        [Parameter(Mandatory)]
        [string]$AliasName
    )
    
    $scriptsDir = Split-Path $PSScriptRoot -Parent
    $connectivityDir = Split-Path $scriptsDir -Parent
    $ipamConfigFile = Join-Path $connectivityDir "config/ipam.json"
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
    <#
    .SYNOPSIS
        Resolves an IPAM block name to a CIDR prefix
    #>
    param(
        [Parameter(Mandatory)]
        [string]$BlockName,
        
        [Parameter(Mandatory = $false)]
        [string]$Space,
        
        [Parameter(Mandatory)]
        [int]$SizeHint
    )
    
    if ($BlockName -match '^\d+\.\d+\.\d+\.\d+/\d+$') {
        Write-Log "Block '$BlockName' is already a CIDR prefix" -Level "INFO"
        return $BlockName
    }
    
    $ipamMapping = @{
        "rai-hub-aue" = "10.0.0.0/20"
        "rai-hub-ause" = "10.0.16.0/20"
        "rai-spokes-aue-prod" = "10.1.0.0/16"
        "rai-platform-mgmt" = "10.5.0.0/22"
        "rai-platform-identity" = "10.5.4.0/23"
        "rai-platform-sharedsvc" = "10.5.6.0/24"
    }
    
    if ($ipamMapping.ContainsKey($BlockName)) {
        Write-Log "Resolved IPAM block '$BlockName' to CIDR: $($ipamMapping[$BlockName])" -Level "INFO"
        return $ipamMapping[$BlockName]
    }
    
    Write-Log "IPAM block '$BlockName' not found in mapping. Please add to IPAM or provide CIDR directly." -Level "WARN"
    Write-Log "Using placeholder CIDR based on size hint: /$SizeHint" -Level "WARN"
    return "10.1.0.0/$SizeHint"
}

function Invoke-IpamAllocation {
    <#
    .SYNOPSIS
        Allocates a CIDR block from IPAM pools with deterministic state management
    #>
    param(
        [Parameter(Mandatory)]
        [string]$AllocationKey,
        
        [Parameter(Mandatory)]
        [int]$CidrSize,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionAlias
    )
    
    $scriptsDir = Split-Path $PSScriptRoot -Parent
    $connectivityDir = Split-Path $scriptsDir -Parent
    $configFile = Join-Path $connectivityDir "config/ipam.json"
    $stateFile = Join-Path (Join-Path $scriptsDir "generated") "ipam-state.json"
    
    if (!(Test-Path $configFile)) {
        Write-Log "IPAM config file not found: $configFile" -Level "WARN"
        return $null
    }
    
    $ipamConfig = Get-IpamConfig -AliasName $SubscriptionAlias
    if (!$ipamConfig -or !$ipamConfig.space -or !$ipamConfig.block) {
        Write-Log "IPAM config missing space/block for subscription '$SubscriptionAlias'" -Level "WARN"
        return $null
    }
    
    $baseCidr = Resolve-IpamBlock -BlockName $ipamConfig.block -Space $ipamConfig.space -SizeHint $CidrSize
    if (!$baseCidr) {
        Write-Log "Could not resolve base CIDR for block '$($ipamConfig.block)'" -Level "WARN"
        return $null
    }
    
    $stateDir = Split-Path $stateFile -Parent
    if (!(Test-Path $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    
    $state = @{ allocations = @() }
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content $stateFile -Raw | ConvertFrom-Json
            if (!$state.allocations) {
                $state.allocations = @()
            }
        }
        catch {
            Write-Log "Failed to load IPAM state, starting fresh: $_" -Level "WARN"
            $state = @{ allocations = @() }
        }
    }
    
    # Ensure allocations is always an array
    if (!$state.allocations) {
        $state.allocations = @()
    }
    $stateAllocations = @($state.allocations)
    
    $existing = $stateAllocations | Where-Object { $_.allocationKey -eq $AllocationKey } | Select-Object -First 1
    if ($existing) {
        Write-Log "Allocation key '$AllocationKey' already exists: $($existing.cidr)" -Level "INFO"
        return $existing.cidr
    }
    
    # Get block allocations - ensure result is always an array, never null
    $blockAllocations = @($stateAllocations | Where-Object { 
        $_.space -eq $ipamConfig.space -and $_.block -eq $ipamConfig.block 
    } | ForEach-Object { $_.cidr } | Where-Object { $null -ne $_ })
    
    $allocatedCidr = Get-NextAvailableCidr -BaseCidr $baseCidr -RequestedSize $CidrSize -AllocatedCidrs $blockAllocations
    
    if (!$allocatedCidr) {
        Write-Log "No available CIDR block of size /$CidrSize in $baseCidr" -Level "WARN"
        return $null
    }
    
    $allocation = @{
        allocationKey = $AllocationKey
        cidr = $allocatedCidr
        cidrSize = $CidrSize
        space = $ipamConfig.space
        block = $ipamConfig.block
        allocatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        status = "allocated"
    }
    
    $state.allocations += $allocation
    
    try {
        $state | ConvertTo-Json -Depth 10 | Set-Content $stateFile -Force
        Write-Log "Allocated CIDR: $allocatedCidr" -Level "SUCCESS"
        return $allocatedCidr
    }
    catch {
        Write-Log "Failed to save IPAM state: $_" -Level "WARN"
        return $null
    }
}

function Get-NextAvailableCidr {
    param(
        [Parameter(Mandatory)]
        [string]$BaseCidr,
        
        [Parameter(Mandatory)]
        [int]$RequestedSize,
        
        [Parameter(Mandatory = $false)]
        [array]$AllocatedCidrs = @()
    )
    
    $baseParts = $BaseCidr -split '/'
    $basePrefix = [int]$baseParts[1]
    
    $baseDecimalObj = Convert-CidrToDecimal -Cidr $BaseCidr
    $baseStart = $baseDecimalObj.Decimal
    $baseSize = [Math]::Pow(2, 32 - $basePrefix)
    $requestedSizeInIps = [Math]::Pow(2, 32 - $RequestedSize)
    
    if ($requestedSizeInIps -gt $baseSize) {
        return $null
    }
    
    $allocatedRanges = @()
    foreach ($allocated in $AllocatedCidrs) {
        $allocParts = $allocated -split '/'
        $allocDecimalObj = Convert-CidrToDecimal -Cidr $allocated
        $allocatedRanges += @{
            Start = $allocDecimalObj.Decimal
            End = $allocDecimalObj.Decimal + [Math]::Pow(2, 32 - [int]$allocParts[1]) - 1
        }
    }
    
    $allocatedRanges = $allocatedRanges | Sort-Object -Property Start
    
    $currentStart = $baseStart
    $baseEnd = $baseStart + $baseSize - 1
    
    foreach ($range in $allocatedRanges) {
        if ($currentStart + $requestedSizeInIps - 1 -lt $range.Start) {
            $resultCidr = Convert-DecimalToCidr -Decimal $currentStart -Prefix $RequestedSize
            return $resultCidr
        }
        $currentStart = [Math]::Max($currentStart, $range.End + 1)
    }
    
    if ($currentStart + $requestedSizeInIps - 1 -le $baseEnd) {
        $resultCidr = Convert-DecimalToCidr -Decimal $currentStart -Prefix $RequestedSize
        return $resultCidr
    }
    
    return $null
}

function Get-SubnetBlueprint {
    <#
    .SYNOPSIS
        Loads a subnet blueprint/profile from JSON file
    #>
    param(
        [Parameter(Mandatory)]
        [string]$BlueprintKey
    )
    
    # Use same path resolution pattern as Get-IpamConfig
    $scriptsDir = Split-Path $PSScriptRoot -Parent
    $connectivityDir = Split-Path $scriptsDir -Parent
    $blueprintFile = Join-Path $connectivityDir "config/subnet-blueprints.json"
    
    if (!(Test-Path $blueprintFile)) {
        Write-Log "Subnet blueprint file not found: $blueprintFile" -Level "WARN"
        return $null
    }
    
    try {
        $blueprints = Get-Content $blueprintFile -Raw | ConvertFrom-Json
        
        # Check profiles first (new format with keys like "spoke.workload.standard")
        if ($blueprints.profiles -and $blueprints.profiles.$BlueprintKey) {
            Write-Log "Found subnet blueprint in profiles: $BlueprintKey" -Level "INFO"
            return $blueprints.profiles.$BlueprintKey
        }
        
        # Fall back to blueprints (legacy format)
        if ($blueprints.blueprints -and $blueprints.blueprints.$BlueprintKey) {
            Write-Log "Found subnet blueprint in blueprints (legacy): $BlueprintKey" -Level "INFO"
            return $blueprints.blueprints.$BlueprintKey
        }
        
        # Also check subnetBlueprints (alternative legacy key name)
        if ($blueprints.subnetBlueprints -and $blueprints.subnetBlueprints.$BlueprintKey) {
            Write-Log "Found subnet blueprint in subnetBlueprints: $BlueprintKey" -Level "INFO"
            return $blueprints.subnetBlueprints.$BlueprintKey
        }
        
        Write-Log "Blueprint key '$BlueprintKey' not found in profiles, blueprints, or subnetBlueprints" -Level "WARN"
    }
    catch {
        Write-Log "Failed to load subnet blueprint: $_" -Level "WARN"
    }
    
    return $null
}

function Convert-CidrToDecimal {
    <#
    .SYNOPSIS
        Converts a CIDR notation to decimal representation
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Cidr
    )
    
    $parts = $Cidr -split '/'
    $ip = $parts[0]
    $prefix = [int]$parts[1]
    
    $octets = $ip -split '\.'
    $decimal = ([int]$octets[0] * 16777216) + ([int]$octets[1] * 65536) + ([int]$octets[2] * 256) + [int]$octets[3]
    
    return @{
        Decimal = $decimal
        Prefix = $prefix
    }
}

function Convert-DecimalToCidr {
    <#
    .SYNOPSIS
        Converts a decimal IP address to CIDR notation
    #>
    param(
        [Parameter(Mandatory)]
        [long]$Decimal,
        
        [Parameter(Mandatory)]
        [int]$Prefix
    )
    
    $octet1 = [Math]::Floor($Decimal / 16777216) % 256
    $octet2 = [Math]::Floor($Decimal / 65536) % 256
    $octet3 = [Math]::Floor($Decimal / 256) % 256
    $octet4 = $Decimal % 256
    
    return "$octet1.$octet2.$octet3.$octet4/$Prefix"
}

function Generate-Subnets {
    <#
    .SYNOPSIS
        Generates subnet definitions from a VNet CIDR and blueprint
    #>
    param(
        [Parameter(Mandatory)]
        [string]$VnetCidr,
        
        [Parameter(Mandatory)]
        [object]$Blueprint
    )
    
    $vnetDecimalObj = Convert-CidrToDecimal -Cidr $VnetCidr
    $vnetStart = $vnetDecimalObj.Decimal
    $vnetSize = [Math]::Pow(2, 32 - $vnetDecimalObj.Prefix)
    
    $subnets = @()
    $currentOffset = 0
    
    foreach ($subnetDef in $Blueprint.subnets) {
        $subnetSize = [Math]::Pow(2, 32 - $subnetDef.cidrSize)
        
        if ($currentOffset + $subnetSize -gt $vnetSize) {
            Write-Log "Subnet '$($subnetDef.name)' exceeds VNet capacity" -Level "WARN"
            break
        }
        
        $subnetStart = $vnetStart + $currentOffset
        $subnetCidr = Convert-DecimalToCidr -Decimal $subnetStart -Prefix $subnetDef.cidrSize
        
        $subnet = @{
            name = $subnetDef.name
            addressPrefix = $subnetCidr
            purpose = if ($subnetDef.purpose) { $subnetDef.purpose } else { $subnetDef.name }
        }
        
        if ($subnetDef.associateNsg) {
            $subnet.associateNsg = $subnetDef.associateNsg
        }
        
        if ($subnetDef.associateRouteTable) {
            $subnet.associateRouteTable = $subnetDef.associateRouteTable
        }
        
        $subnets += $subnet
        $currentOffset += $subnetSize
    }
    
    return $subnets
}

Export-ModuleMember -Function Get-IpamConfig, Resolve-IpamBlock, Invoke-IpamAllocation, `
    Get-SubnetBlueprint, Convert-CidrToDecimal, Convert-DecimalToCidr, Generate-Subnets
