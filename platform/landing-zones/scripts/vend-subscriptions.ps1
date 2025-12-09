
# =============================================================================
# Subscription Vending Script
# =============================================================================
# Creates demo/test subscriptions using Azure CLI subscription alias API
# 
# Prerequisites:
# - Azure CLI installed and authenticated
# - Permissions to create subscriptions (Owner on billing scope)
# - PowerShell 7.0 or later
#
# Usage:
#   .\vend-subscriptions.ps1
#   .\vend-subscriptions.ps1 -Verbose
# =============================================================================

[CmdletBinding()]
param(
    [Parameter()]
    [string]$LendingCoreDisplayName = "Lending Core Subscription",

    [Parameter()]
    [string]$FraudEngineDisplayName = "Fraud Engine Subscription",

    [Parameter()]
    [string]$Workload = "Production",

    [Parameter()]
    [string]$OutputFile = "subscription-ids.json"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Azure Subscription Vending" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Test-AzureCLI {
    $az = az --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Azure CLI is not installed or not authenticated" -ForegroundColor Red
        return $false
    }
    Write-Host "✓ Azure CLI is available" -ForegroundColor Green
    return $true
}

function Create-Subscription {
    param(
        [string]$SubscriptionName,
        [string]$DisplayName,
        [string]$Workload,
        [string]$BillingScope
    )
    
    Write-Host ""
    Write-Host "Creating subscription: $DisplayName..." -ForegroundColor Yellow
    
    # Create the subscription alias with MCA billing scope
    $createResult = az account alias create `
        --name $SubscriptionName `
        --display-name $DisplayName `
        --workload $Workload `
        --billing-scope $BillingScope `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $alias = $createResult | ConvertFrom-Json
        Write-Host "✓ Subscription alias created: $SubscriptionName" -ForegroundColor Green
        return $alias
    }
    else {
        Write-Host "✗ Failed to create subscription: $createResult" -ForegroundColor Red
        return $null
    }
}

function Get-SubscriptionId {
    param(
        [string]$SubscriptionName
    )
    
    Write-Host "Retrieving subscription ID for: $SubscriptionName..." -ForegroundColor Gray
    
    # List subscriptions and find by name
    $subscriptions = az account list --output json | ConvertFrom-Json
    $subscription = $subscriptions | Where-Object { $_.name -eq $SubscriptionName }
    
    if ($subscription) {
        $subId = $subscription.id
        Write-Host "✓ Found subscription ID: $subId" -ForegroundColor Green
        return $subId
    }
    else {
        Write-Host "✗ Subscription not found: $SubscriptionName" -ForegroundColor Red
        return $null
    }
}

function Assign-ToManagementGroup {
    param(
        [string]$SubscriptionId,
        [string]$ManagementGroupName
    )
    
    Write-Host "Assigning subscription to management group: $ManagementGroupName..." -ForegroundColor Gray
    
    $assignResult = az account management-group subscription add `
        --name $ManagementGroupName `
        --subscription $SubscriptionId `
        --output json 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Subscription assigned to management group" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "✗ Failed to assign subscription: $assignResult" -ForegroundColor Yellow
        Write-Host "   (This is expected if the management group doesn't exist yet)" -ForegroundColor Gray
        return $false
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# MCA Billing Scope Configuration
$billingAccountName = "d36492e8-d509-51ee-1f74-74e4eebc6559:c008f2fd-b18a-4631-84b1-cadcf244af11_2019-05-31"
$billingProfileName = "N5VT-LLSF-BG7-PGB"
$invoiceSectionName = "7D6M-GK3C-PJA-PGB"

$billingScope = "/providers/Microsoft.Billing/billingAccounts/$billingAccountName/billingProfiles/$billingProfileName/invoiceSections/$invoiceSectionName"

Write-Host "Using MCA Billing Scope:" -ForegroundColor Cyan
Write-Host "  Account: $billingAccountName" -ForegroundColor Gray
Write-Host "  Profile: $billingProfileName" -ForegroundColor Gray
Write-Host "  Invoice Section: $invoiceSectionName" -ForegroundColor Gray
Write-Host ""

# Verify Azure CLI
if (-not (Test-AzureCLI)) {
    exit 1
}

Write-Host ""

# Create subscriptions
$lendingCoreAlias = Create-Subscription -SubscriptionName "lending-core-sub" `
                                        -DisplayName $LendingCoreDisplayName `
                                        -Workload $Workload `
                                        -BillingScope $billingScope

$fraudEngineAlias = Create-Subscription -SubscriptionName "fraud-engine-sub" `
                                        -DisplayName $FraudEngineDisplayName `
                                        -Workload $Workload `
                                        -BillingScope $billingScope

# If subscriptions were created, retrieve their IDs
if ($lendingCoreAlias -or $fraudEngineAlias) {
    Write-Host ""
    Write-Host "Waiting for subscriptions to be fully provisioned..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10  # Wait longer for subscriptions to appear in the list
    
    $lendingCoreId = Get-SubscriptionId -SubscriptionName $LendingCoreDisplayName
    if (-not $lendingCoreId) {
        # Try with alias name if display name doesn't work
        $lendingCoreId = Get-SubscriptionId -SubscriptionName "lending-core-sub"
    }
    
    $fraudEngineId = Get-SubscriptionId -SubscriptionName $FraudEngineDisplayName
    if (-not $fraudEngineId) {
        # Try with alias name if display name doesn't work
        $fraudEngineId = Get-SubscriptionId -SubscriptionName "fraud-engine-sub"
    }
    
    # Attempt to assign to management groups
    if ($lendingCoreId) {
        Assign-ToManagementGroup -SubscriptionId $lendingCoreId -ManagementGroupName "landing-zones"
    }
    
    if ($fraudEngineId) {
        Assign-ToManagementGroup -SubscriptionId $fraudEngineId -ManagementGroupName "landing-zones"
    }
    
    # Output results
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Subscription Vending Complete" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Lending Core Subscription ID: $lendingCoreId" -ForegroundColor Green
    Write-Host "Fraud Engine Subscription ID: $fraudEngineId" -ForegroundColor Green
    Write-Host ""
    
    # Save to file
    $output = @{
        lendingCoreSubscriptionId = $lendingCoreId
        fraudEngineSubscriptionId = $fraudEngineId
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $output | ConvertTo-Json | Set-Content -Path $OutputFile -Encoding UTF8
    Write-Host "Subscription IDs saved to: $OutputFile" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Use the subscription IDs above to update capabilities-final YAML files" -ForegroundColor Gray
    Write-Host "2. Replace <PLACEHOLDER-LENDING-SUB-ID> with: $lendingCoreId" -ForegroundColor Gray
    Write-Host "3. Replace <PLACEHOLDER-FRAUD-SUB-ID> with: $fraudEngineId" -ForegroundColor Gray
    Write-Host ""
}
else {
    Write-Host ""
    Write-Host "ERROR: No subscriptions were created" -ForegroundColor Red
    exit 1
}

