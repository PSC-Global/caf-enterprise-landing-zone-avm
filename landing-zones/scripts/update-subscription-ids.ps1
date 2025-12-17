# Update Subscription IDs in Capabilities-Final YAML Files
# Moved from platform/landing-zones/scripts/update-subscription-ids.ps1

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SubscriptionIdsFile = "./subscription-ids.json",

    [Parameter()]
    [string]$CapabilitiesFinalPath = "../../platform/identity/config/capabilities-final"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Update Subscription IDs in YAML Files" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Validation
if (-not (Test-Path $SubscriptionIdsFile)) {
    Write-Host "ERROR: Subscription IDs file not found: $SubscriptionIdsFile" -ForegroundColor Red
    Write-Host "Run vend-subscriptions.ps1 first to create subscription IDs" -ForegroundColor Yellow
    exit 1
}

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

if (-not (Test-Path $CapabilitiesFinalPath)) {
    Write-Host "ERROR: Capabilities-final directory not found: $CapabilitiesFinalPath" -ForegroundColor Red
    Write-Host "Make sure you run this script from landing-zones/scripts/" -ForegroundColor Yellow
    exit 1
}

Write-Host "Updating YAML files in: $CapabilitiesFinalPath" -ForegroundColor Yellow
Write-Host ""

$yamlFiles = Get-ChildItem -Path $CapabilitiesFinalPath -Filter "*.yaml" | Sort-Object Name
$updatedCount = 0

foreach ($file in $yamlFiles) {
    Write-Host "Processing: $($file.Name)..." -ForegroundColor Gray

    $content = Get-Content -Path $file.FullName -Raw
    $originalContent = $content

    $content = $content -replace '<PLACEHOLDER-LENDING-SUB-ID>', $lendingCoreId
    $content = $content -replace '<PLACEHOLDER-FRAUD-SUB-ID>', $fraudEngineId

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
