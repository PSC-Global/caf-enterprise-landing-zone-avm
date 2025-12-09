param(
    [string]$MappingFile = (Join-Path $PSScriptRoot "../bicep/role-definition-ids.json")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $MappingFile)) {
    Write-Host "ERROR: Mapping file not found: $MappingFile" -ForegroundColor Red
    exit 1
}

Write-Host "Validating role mapping file: $MappingFile" -ForegroundColor Cyan

$mapping = Get-Content $MappingFile -Raw | ConvertFrom-Json -AsHashtable

# Check for duplicate role names (keys)
$roleNames = @($mapping.Keys)
$duplicateNames = $roleNames | Group-Object | Where-Object { $_.Count -gt 1 }

if ($duplicateNames) {
    Write-Host "ERROR: Duplicate role names found:" -ForegroundColor Red
    foreach ($dup in $duplicateNames) {
        Write-Host "  - $($dup.Name) (appears $($dup.Count) times)" -ForegroundColor Yellow
    }
    exit 1
}

# Check for duplicate GUIDs (values)
$guids = @($mapping.Values)
$duplicateGuids = $guids | Group-Object | Where-Object { $_.Count -gt 1 }

if ($duplicateGuids) {
    Write-Host "ERROR: Duplicate GUIDs found:" -ForegroundColor Red
    foreach ($dup in $duplicateGuids) {
        $roles = @()
        foreach ($key in $mapping.Keys) {
            if ($mapping[$key] -eq $dup.Name) {
                $roles += $key
            }
        }
        Write-Host "  - GUID $($dup.Name) is used by multiple roles:" -ForegroundColor Yellow
        Write-Host "    $($roles -join ', ')" -ForegroundColor Yellow
    }
    exit 1
}

# Validate GUID format (should be valid UUID format)
$invalidGuids = @()
foreach ($key in $mapping.Keys) {
    $guid = $mapping[$key]
    if ($guid -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        $invalidGuids += @{
            Role = $key
            GUID = $guid
        }
    }
}

if ($invalidGuids) {
    Write-Host "WARNING: Invalid GUID format found:" -ForegroundColor Yellow
    foreach ($item in $invalidGuids) {
        Write-Host "  - $($item.Role): $($item.GUID)" -ForegroundColor Yellow
    }
}

Write-Host "✓ Validation passed!" -ForegroundColor Green
Write-Host "  Total roles: $($roleNames.Count)" -ForegroundColor Gray
Write-Host "  Unique GUIDs: $($guids.Count)" -ForegroundColor Gray

exit 0

