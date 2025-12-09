# =============================================================================
# Update Subscription IDs in Capabilities-Final YAML Files
# =============================================================================
# Reads subscription IDs from subscription-ids.json and updates all
# capabilities-final YAML files with real subscription IDs instead of
# placeholders.
#
# Prerequisites:
# - vend-subscriptions.ps1 has been run and created subscription-ids.json
# - PowerShell 7.0 or later
#
# Usage:
#   .\update-subscription-ids.ps1
#   .\update-subscription-ids.ps1 -SubscriptionIdsFile "./subscription-ids.json"
# =============================================================================

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SubscriptionIdsFile = "./subscription-ids.json",

    [Parameter()]
    [string]$CapabilitiesFinalPath = "../../identity/config/capabilities-final"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Update Subscription IDs in YAML Files" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# VALIDATION
# =============================================================================

# Check if subscription IDs file exists
if (-not (Test-Path $SubscriptionIdsFile)) {
    Write-Host "ERROR: Subscription IDs file not found: $SubscriptionIdsFile" -ForegroundColor Red
    Write-Host "Run vend-subscriptions.ps1 first to create subscription IDs" -ForegroundColor Yellow
    exit 1
}

# Read subscription IDs
Write-Host "Reading subscription IDs from: $SubscriptionIdsFile" -ForegroundColor Yellow
$subscriptionIds = Get-Content $SubscriptionIdsFile | ConvertFrom-Json

$lendingCoreId = $subscriptionIds.lendingCoreSubscriptionId
$fraudEngineId = $subscriptionIds.fraudEngineSubscriptionId

if (-not $lendingCoreId -or -not $fraudEngineId) {
    Write-Host "ERROR: Subscription IDs not found in file" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Lending Core Subscription ID: $lendingCoreId" -ForegroundColor Green
Write-Host "✓ Fraud Engine Subscription ID: $fraudEngineId" -ForegroundColor Green
Write-Host ""

# Check if capabilities-final directory exists
if (-not (Test-Path $CapabilitiesFinalPath)) {
    Write-Host "ERROR: Capabilities-final directory not found: $CapabilitiesFinalPath" -ForegroundColor Red
    Write-Host "Make sure you run this script from platform/landing-zones/scripts/" -ForegroundColor Yellow
    exit 1
}

Write-Host "Updating YAML files in: $CapabilitiesFinalPath" -ForegroundColor Yellow
Write-Host ""

# =============================================================================
# UPDATE YAML FILES
# =============================================================================

$yamlFiles = Get-ChildItem -Path $CapabilitiesFinalPath -Filter "*.yaml" | Sort-Object Name
$updatedCount = 0

foreach ($file in $yamlFiles) {
    Write-Host "Processing: $($file.Name)..." -ForegroundColor Gray
    
    # Read file content
    $content = Get-Content -Path $file.FullName -Raw
    
    # Track if changes were made
    $originalContent = $content
    
    # Replace placeholders
    $content = $content -replace '<PLACEHOLDER-LENDING-SUB-ID>', $lendingCoreId
    $content = $content -replace '<PLACEHOLDER-FRAUD-SUB-ID>', $fraudEngineId
    
    # Write back if changed
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -Encoding UTF8
        $updatedCount++
        Write-Host "  ✓ Updated with real subscription IDs" -ForegroundColor Green
    }
    else {
        Write-Host "  - No placeholders found" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Update Complete" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Updated $updatedCount YAML files with real subscription IDs" -ForegroundColor Green
Write-Host ""

# =============================================================================
# VERIFICATION
# =============================================================================

Write-Host "Verification - Sample from compute.yaml:" -ForegroundColor Yellow
Write-Host ""
$sampleFile = Join-Path $CapabilitiesFinalPath "compute.yaml"
if (Test-Path $sampleFile) {
    $sampleContent = Get-Content $sampleFile | Select-Object -First 20
    $sampleContent | ForEach-Object { Write-Host "  $_" }
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Verify the subscription IDs are correct in the YAML files above" -ForegroundColor Gray
Write-Host "2. Run the sync-aad-groups.ps1 script to create AAD groups" -ForegroundColor Gray
Write-Host "3. Deploy role assignments using role-assignments.bicep" -ForegroundColor Gray
Write-Host ""
