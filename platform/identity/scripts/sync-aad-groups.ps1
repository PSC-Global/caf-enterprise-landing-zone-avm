param(
    [string]$CapabilitiesPath = (Join-Path $PSScriptRoot "..\config\capabilities")
)

$mappingPath = Join-Path $PSScriptRoot "..\config\aad-group-mapping.json"

# Load all capability files to determine all possible groups
$allGroups = @{}

Get-ChildItem $CapabilitiesPath -Filter *.yaml | ForEach-Object {
    $cap = (Get-Content $_.FullName | ConvertFrom-Yaml)
    $capabilityName = $cap.capability
    
    # Create groups for each access level in this capability
    foreach ($level in $cap.accessLevels.Keys) {
        $groupName = "rai-$capabilityName-$level"
        if (-not $allGroups.ContainsKey($groupName)) {
            $allGroups[$groupName] = $true
        }
    }
}

Write-Host "Creating/finding all capability groups from catalog..." -ForegroundColor Cyan
Write-Host "Total groups to process: $($allGroups.Keys.Count)" -ForegroundColor Green

$groupMap = @{}

# Create or find each group
foreach ($groupName in $allGroups.Keys) {
    # Lookup group
    $existing = az ad group show --group $groupName --query id -o tsv 2>$null

    if (-not $existing) {
        Write-Host "Creating group: $groupName" -ForegroundColor Yellow
        $existing = az ad group create --display-name $groupName --mail-nickname $groupName --query id -o tsv
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to create group $groupName"
            continue
        }
    } else {
        Write-Host "Found existing group: $groupName" -ForegroundColor Gray
    }

    $groupMap[$groupName] = $existing
}

$groupMap | ConvertTo-Json | Set-Content $mappingPath -Force
Write-Host "`nAAD mapping file updated: $mappingPath" -ForegroundColor Green
Write-Host "Total groups in mapping: $($groupMap.Keys.Count)" -ForegroundColor Green
