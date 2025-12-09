param(
    [Parameter(Mandatory = $false)]
    [string]$Location = "australiaeast",
    
    [Parameter(Mandatory = $false)]
    [string]$AssignmentsFile = (Join-Path $PSScriptRoot "../bicep/generated-role-assignments.json"),
    
    [Parameter(Mandatory = $false)]
    [string]$AadGroupIdsFile = (Join-Path $PSScriptRoot "../bicep/aad-group-ids.json"),
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionTemplate = (Join-Path $PSScriptRoot "../bicep/role-assignments-subscription.bicep"),
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupTemplate = (Join-Path $PSScriptRoot "../bicep/role-assignments-resourcegroup.bicep")
)

$ErrorActionPreference = "Stop"

Write-Host "Deploying role assignments..." -ForegroundColor Cyan

# Load assignments
$allAssignments = Get-Content $AssignmentsFile | ConvertFrom-Json

if ($allAssignments.Count -eq 0) {
    Write-Host "No assignments found. Skipping deployment." -ForegroundColor Yellow
    exit 0
}

# Group assignments by scope type
$subscriptionAssignments  = $allAssignments | Where-Object { $_.scopeType -eq 'subscription' }
$resourceGroupAssignments = $allAssignments | Where-Object { $_.scopeType -eq 'resourceGroup' }

Write-Host "Found $($subscriptionAssignments.Count) subscription-scoped assignments" -ForegroundColor Green
Write-Host "Found $($resourceGroupAssignments.Count) resourceGroup-scoped assignments" -ForegroundColor Green

# ============================================================================
# Deploy Subscription-Scoped Assignments
# ============================================================================
if ($subscriptionAssignments.Count -gt 0) {
    # Group by subscription ID (scopeValue)
    $subGroups = $subscriptionAssignments | Group-Object -Property scopeValue
    
    foreach ($subGroup in $subGroups) {
        $subscriptionId = $subGroup.Name
        Write-Host "`nDeploying subscription-scoped assignments to: $subscriptionId" -ForegroundColor Yellow
        
        # Set subscription
        az account set --subscription $subscriptionId | Out-Null
        $currentSub = az account show --query id -o tsv
        if ($currentSub -ne $subscriptionId) {
            Write-Warning "Failed to set subscription. Current: $currentSub, Expected: $subscriptionId. Skipping."
            continue
        }
        
        # Deploy
        $deploymentName = "role-assignments-sub-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        az deployment sub create `
            --location $Location `
            --name $deploymentName `
            --template-file $SubscriptionTemplate `
            --parameters assignments=@$AssignmentsFile `
            --parameters aadGroupIds=@$AadGroupIdsFile
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Subscription deployment successful!" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Subscription deployment failed" -ForegroundColor Red
        }
    }
}

# ============================================================================
# Deploy ResourceGroup-Scoped Assignments
# ============================================================================
if ($resourceGroupAssignments.Count -gt 0) {
    # Group by subscription ID + resource group name
    $rgGroups = $resourceGroupAssignments | Group-Object -Property @{ Expression = { $_.scopeValue + '|' + $_.resourceGroup } }
    
    foreach ($rgGroup in $rgGroups) {
        $parts = $rgGroup.Name -split '\|'
        $subscriptionId    = $parts[0]
        $resourceGroupName = $parts[1]
        
        Write-Host "`nDeploying resourceGroup-scoped assignments to: $subscriptionId / $resourceGroupName" -ForegroundColor Yellow
        
        # Set subscription
        az account set --subscription $subscriptionId | Out-Null
        $currentSub = az account show --query id -o tsv
        if ($currentSub -ne $subscriptionId) {
            Write-Warning "Failed to set subscription. Current: $currentSub, Expected: $subscriptionId. Skipping."
            continue
        }
        
        # Check if resource group exists
        $rgExists = az group show --name $resourceGroupName --query id -o tsv 2>$null
        if (-not $rgExists) {
            Write-Warning "Resource group '$resourceGroupName' does not exist in subscription $subscriptionId. Skipping."
            continue
        }
        
        # Deploy
        $deploymentName = "role-assignments-rg-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        az deployment group create `
            --resource-group $resourceGroupName `
            --name $deploymentName `
            --template-file $ResourceGroupTemplate `
            --parameters assignments=@$AssignmentsFile `
            --parameters aadGroupIds=@$AadGroupIdsFile `
            --parameters subscriptionId=$subscriptionId `
            --parameters resourceGroupName=$resourceGroupName
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ ResourceGroup deployment successful!" -ForegroundColor Green
        } else {
            Write-Host "  ✗ ResourceGroup deployment failed" -ForegroundColor Red
        }
    }
}

Write-Host "`nDeployment complete!" -ForegroundColor Cyan
