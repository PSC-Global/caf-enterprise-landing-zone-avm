param(
    [string]$ProjectsPath = (Join-Path $PSScriptRoot "..\config\projects")
)

$mappingPath = Join-Path $PSScriptRoot "..\config\aad-group-mapping.json"
$generatedPath = Join-Path $PSScriptRoot "..\generated"
if (-not (Test-Path $generatedPath)) {
    New-Item -ItemType Directory -Path $generatedPath -Force | Out-Null
}
$groupIdsPath = Join-Path $generatedPath "group-ids.json"

# Load all project YAML files to determine all groups needed
$allGroups = @{}

Write-Host "Scanning project YAML files for group definitions..." -ForegroundColor Cyan

Get-ChildItem $ProjectsPath -Filter *.yaml | ForEach-Object {
    $projectFile = $_
    $proj = (Get-Content $projectFile.FullName | ConvertFrom-Yaml)
    $projectName = $proj.project

    if (-not $projectName) {
        Write-Warning "Project file $($projectFile.Name) does not have a 'project' field. Skipping."
        return
    }

    # Handle environments structure
    if (-not $proj.environments) {
        Write-Warning "Project $projectName does not have 'environments' defined. Skipping."
        return
    }

    # Get environment names - handle both hashtable and PSCustomObject
    $environmentsObj = $proj.environments
    if ($environmentsObj -is [hashtable] -or $environmentsObj -is [System.Collections.IDictionary]) {
        $envNames = $environmentsObj.Keys
    } else {
        $envNames = $environmentsObj.PSObject.Properties.Name
    }

    # Loop through environments
    foreach ($envName in $envNames) {
        if ($environmentsObj -is [hashtable] -or $environmentsObj -is [System.Collections.IDictionary]) {
            $env = $environmentsObj[$envName]
        } else {
            $env = $environmentsObj.$envName
        }

        if (-not $env.capabilities) {
            Write-Warning "Environment $envName in project $projectName has no capabilities. Skipping."
            continue
        }

        # Get capability names
        if ($env.capabilities -is [hashtable] -or $env.capabilities -is [System.Collections.IDictionary]) {
            $capabilityNames = $env.capabilities.Keys
        } else {
            $capabilityNames = $env.capabilities.PSObject.Properties.Name
        }

        # Loop through capabilities
        foreach ($capability in $capabilityNames) {
            # Get levels for this capability
            if ($env.capabilities -is [hashtable] -or $env.capabilities -is [System.Collections.IDictionary]) {
                $levelArray = $env.capabilities[$capability]
            } else {
                $levelArray = $env.capabilities.$capability
            }

            # Create group for each capability+level combination
            foreach ($level in $levelArray) {
                $groupName = "rai-$projectName-$envName-$capability-$level"
                if (-not $allGroups.ContainsKey($groupName)) {
                    $allGroups[$groupName] = $true
                }
            }
        }
    }
}

Write-Host "Creating/finding all project-environment-capability-level groups..." -ForegroundColor Cyan
Write-Host "Total groups to process: $($allGroups.Keys.Count)" -ForegroundColor Green

$groupMap = @{}

# Create or find each group
$newGroupsCreated = $false
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
        $newGroupsCreated = $true
        Write-Host "  ✓ Created with ID: $existing" -ForegroundColor Green
    } else {
        Write-Host "Found existing group: $groupName" -ForegroundColor Gray
    }

    $groupMap[$groupName] = $existing
}

# If new groups were created, wait for replication (Azure AD replication can take a few seconds)
if ($newGroupsCreated) {
    Write-Host "`nWaiting 10 seconds for Entra ID replication..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    
    # Verify all groups are accessible
    Write-Host "Verifying groups are accessible..." -ForegroundColor Cyan
    $verificationFailed = $false
    foreach ($groupName in $groupMap.Keys) {
        $groupId = $groupMap[$groupName]
        $verify = az ad group show --group $groupId --query id -o tsv 2>$null
        if (-not $verify -or $verify -ne $groupId) {
            Write-Warning "Group $groupName (ID: $groupId) not yet accessible. Replication may still be in progress."
            $verificationFailed = $true
        }
    }
    
    if ($verificationFailed) {
        Write-Warning "`nSome groups may not be fully replicated yet. Consider waiting a few more seconds before deploying."
    } else {
        Write-Host "✓ All groups verified and accessible" -ForegroundColor Green
    }
}

# Write to both locations for backward compatibility during transition
$groupMap | ConvertTo-Json | Set-Content $mappingPath -Force
$groupMap | ConvertTo-Json | Set-Content $groupIdsPath -Force

Write-Host "`nAAD mapping file updated: $mappingPath" -ForegroundColor Green
Write-Host "Group IDs file updated: $groupIdsPath" -ForegroundColor Green
Write-Host "Total groups in mapping: $($groupMap.Keys.Count)" -ForegroundColor Green
