param(
    [string[]]$Projects
)

$basePath        = Join-Path $PSScriptRoot "..\config"
$capabilityPath  = Join-Path $basePath "capabilities"
$projectPath     = Join-Path $basePath "projects"
$outputFile      = Join-Path $PSScriptRoot "..\bicep\generated-role-assignments.json"

# Load capability catalog: capability -> accessLevels
$allCapabilities = @{}
Get-ChildItem $capabilityPath -Filter *.yaml | ForEach-Object {
    $cap = (Get-Content $_.FullName | ConvertFrom-Yaml)
    $allCapabilities[$cap.capability] = $cap.accessLevels
}

$assignments = @()

# Loop through selected project files
Get-ChildItem $projectPath -Filter *.yaml | ForEach-Object {
    $projectFile = $_
    $projectName = $projectFile.BaseName

    if ($Projects -and -not ($Projects.Contains($projectName))) {
        return
    }

    $proj = (Get-Content $projectFile.FullName | ConvertFrom-Yaml)

    # Detect format: new (environments) vs old (envs)
    if ($proj.environments) {
        # New format: environments is an object/hashtable
        $environmentsObj = $proj.environments
        
        # Get environment names - handle both hashtable and PSCustomObject
        if ($environmentsObj -is [hashtable] -or $environmentsObj -is [System.Collections.IDictionary]) {
            $envNames = $environmentsObj.Keys
        } else {
            $envNames = $environmentsObj.PSObject.Properties.Name
        }
    } elseif ($proj.envs) {
        # Old format: we just warn and skip (force migration)
        Write-Warning "Project $($proj.project) uses old format (envs array). Please migrate to new 'environments' format."
        return
    } else {
        Write-Warning "Project $($proj.project) does not have 'environments' or 'envs' defined. Skipping."
        return
    }

    # Loop through environments (new format)
    foreach ($envName in $envNames) {
        if ($environmentsObj -is [hashtable] -or $environmentsObj -is [System.Collections.IDictionary]) {
            $env = $environmentsObj[$envName]
        } else {
            $env = $environmentsObj.$envName
        }

        $scope = $env.scope

        # ---------------------------------------------------------------------
        # Determine subscription IDs based on scope
        # ---------------------------------------------------------------------
        $subscriptionIds = @()

        if ($scope -eq 'multipleSubscriptions') {
            # For multipleSubscriptions, use the subscriptions array
            if (-not $env.subscriptions) {
                Write-Warning "Environment $envName in project $($proj.project) has scope 'multipleSubscriptions' but no 'subscriptions' array. Skipping."
                continue
            }

            foreach ($sub in $env.subscriptions) {
                if ($sub.id) {
                    $subscriptionIds += $sub.id
                }
            }
        } elseif ($env.subscriptionId) {
            # For resourceGroup or subscription scope, use single subscriptionId
            $subscriptionIds += $env.subscriptionId
        } else {
            Write-Warning "Environment $envName in project $($proj.project) has no subscriptionId or subscriptions array. Skipping."
            continue
        }

        # ---------------------------------------------------------------------
        # Capabilities for this environment
        # ---------------------------------------------------------------------
        if (-not $env.capabilities) {
            Write-Warning "Environment $envName in project $($proj.project) has no capabilities. Skipping."
            continue
        }

        # Get capability names - handle both hashtable and PSCustomObject
        if ($env.capabilities -is [hashtable] -or $env.capabilities -is [System.Collections.IDictionary]) {
            $capabilityNames = $env.capabilities.Keys
        } else {
            $capabilityNames = $env.capabilities.PSObject.Properties.Name
        }
        
        foreach ($capability in $capabilityNames) {

            # Access levels for this capability: e.g. [ "reader", "contributor" ]
            if ($env.capabilities -is [hashtable] -or $env.capabilities -is [System.Collections.IDictionary]) {
                $levelArray = $env.capabilities[$capability]
            } else {
                $levelArray = $env.capabilities.$capability
            }
            
            foreach ($level in $levelArray) {

                if (-not $allCapabilities.ContainsKey($capability)) {
                    Write-Warning "Capability '$capability' not found in capability catalog. Skipping."
                    continue
                }

                if (-not $allCapabilities[$capability].ContainsKey($level)) {
                    Write-Warning "Access level '$level' not found for capability '$capability'. Skipping."
                    continue
                }

                $roleList = $allCapabilities[$capability][$level]

                foreach ($role in $roleList) {
                    # AAD group naming convention: rai-<project>-<env>-<capability>-<level>
                    $aadGroupName = "rai-$($proj.project)-$envName-$capability-$level"

                    # Create assignments for each subscription (handles multipleSubscriptions)
                    foreach ($subscriptionId in $subscriptionIds) {
                        if ($scope -eq 'resourceGroup') {
                            # ResourceGroup scope: scopeValue = subscriptionId, plus resourceGroup name
                            $assignments += [PSCustomObject]@{
                                project       = $proj.project
                                environment   = $envName
                                capability    = $capability
                                level         = $level
                                role          = $role
                                aadGroupName  = $aadGroupName
                                scopeType     = 'resourceGroup'
                                scopeValue    = $subscriptionId
                                resourceGroup = $env.resourceGroup
                            }
                        } elseif ($scope -eq 'subscription' -or $scope -eq 'multipleSubscriptions') {
                            # Subscription scope: scopeValue = subscriptionId
                            $assignments += [PSCustomObject]@{
                                project      = $proj.project
                                environment  = $envName
                                capability   = $capability
                                level        = $level
                                role         = $role
                                aadGroupName = $aadGroupName
                                scopeType    = 'subscription'
                                scopeValue   = $subscriptionId
                            }
                        } else {
                            Write-Warning "Unknown scope type '$scope' for environment $envName in project $($proj.project). Skipping."
                        }
                    }
                }
            }
        }
    }
}

$assignments | ConvertTo-Json -Depth 6 | Set-Content $outputFile -Force

Write-Host "Generated role assignment file:"
Write-Host $outputFile
