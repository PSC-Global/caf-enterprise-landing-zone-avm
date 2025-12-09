param(
    [string]$CapabilitiesPath = (Join-Path $PSScriptRoot "../config/capabilities"),
    [string]$ProjectsPath = (Join-Path $PSScriptRoot "../config/projects"),
    [string]$AssignmentsPath = (Join-Path $PSScriptRoot "../bicep/generated-role-assignments.json"),
    [string]$GroupMappingPath = (Join-Path $PSScriptRoot "../config/aad-group-mapping.json"),
    [string]$BicepParamPath = (Join-Path $PSScriptRoot "../bicep/aad-group-ids.bicepparam"),
    [string]$Projects = ""
)

$ErrorActionPreference = "Stop"
$projectsList = @()
if ($Projects) {
    $projectsList = $Projects.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

if (-not (Test-Path $CapabilitiesPath -PathType Container)) { throw "CapabilitiesPath not found: $CapabilitiesPath" }
if (-not (Test-Path $ProjectsPath -PathType Container)) { throw "ProjectsPath not found: $ProjectsPath" }

# Validate role mapping file before proceeding
& (Join-Path $PSScriptRoot "validate-role-mapping.ps1")

if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { throw "validate-role-mapping.ps1 failed" }

& (Join-Path $PSScriptRoot "generate-capability-access.ps1") -Projects $projectsList

if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { throw "generate-capability-access.ps1 failed" }

& (Join-Path $PSScriptRoot "sync-aad-groups.ps1")

if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { throw "sync-aad-groups.ps1 failed" }

& (Join-Path $PSScriptRoot "generate-bicepparam.ps1")

if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) { throw "generate-bicepparam.ps1 failed" }

Write-Host "Pipeline complete"
Write-Host "Assignments : $AssignmentsPath"
Write-Host "Group map  : $GroupMappingPath"
Write-Host "Bicep param: $BicepParamPath"
