# =============================================================================
# Cleanup Script for vWAN Hub and Firewall (Testing)
# =============================================================================
# Purpose: Delete all resources created by deploy-connectivity.ps1 for testing
# Usage: ./cleanup-connectivity.ps1 -SubscriptionId "rai-platform-connectivity-prod-01"
# =============================================================================

param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId
)

# Load configuration
$ConfigFile = "../../../subscription-vending/config/subscriptions.json"
if (!(Test-Path $ConfigFile)) {
    Write-Host "ERROR: Configuration file not found: $ConfigFile" -ForegroundColor Red
    exit 1
}

$config = Get-Content $ConfigFile | ConvertFrom-Json
$subscription = $config.subscriptions | Where-Object { $_.aliasName -eq $SubscriptionId } | Select-Object -First 1

if (!$subscription) {
    Write-Host "ERROR: Subscription '$SubscriptionId' not found in configuration" -ForegroundColor Red
    exit 1
}

# Resolve subscription ID
$azSubscriptionId = az rest --method GET `
    --uri "https://management.azure.com/providers/Microsoft.Subscription/aliases/$($subscription.aliasName)?api-version=2021-10-01" `
    --query "properties.subscriptionId" -o tsv 2>$null

if ([string]::IsNullOrWhiteSpace($azSubscriptionId)) {
    Write-Host "ERROR: Could not resolve subscription ID for alias '$($subscription.aliasName)'" -ForegroundColor Red
    exit 1
}

az account set --subscription $azSubscriptionId | Out-Null

# Determine resource group name
$subscriptionRole = $subscription.role
$subscriptionPurpose = switch ($subscriptionRole) {
    "hub" { "core" }
    default { "workload" }
}

$networkingRgName = "rg-$subscriptionPurpose-network-$($subscription.primaryRegion)-001"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Cleanup: vWAN Hub and Firewall Resources" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Subscription: $($subscription.aliasName)" -ForegroundColor Yellow
Write-Host "Resource Group: $networkingRgName" -ForegroundColor Yellow
Write-Host "`nWARNING: This will delete ALL resources in the resource group!" -ForegroundColor Red
Write-Host "This includes:" -ForegroundColor Yellow
Write-Host "  - Virtual WAN" -ForegroundColor White
Write-Host "  - Virtual Hub" -ForegroundColor White
Write-Host "  - Azure Firewall" -ForegroundColor White
Write-Host "  - Firewall Policy" -ForegroundColor White
Write-Host "  - Routing Intent" -ForegroundColor White
Write-Host "  - Private DNS Zones (if deployed)" -ForegroundColor White
Write-Host "  - Diagnostic Settings (automatically deleted with resources)" -ForegroundColor White
Write-Host "`nNote: Log Analytics Workspace is NOT deleted (it's in a different subscription)" -ForegroundColor Green

$confirm = Read-Host "`nType 'DELETE' to confirm deletion"

if ($confirm -ne "DELETE") {
    Write-Host "Cleanup cancelled." -ForegroundColor Yellow
    exit 0
}

# Check if resource group exists
$rgExists = az group show --name $networkingRgName --subscription $azSubscriptionId --query "name" -o tsv 2>$null

if (!$rgExists) {
    Write-Host "Resource group '$networkingRgName' does not exist. Nothing to clean up." -ForegroundColor Green
    exit 0
}

# Delete resource group (this deletes all resources inside)
Write-Host "`nDeleting resource group and all resources..." -ForegroundColor Yellow
az group delete `
    --name $networkingRgName `
    --subscription $azSubscriptionId `
    --yes `
    --no-wait

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nResource group deletion initiated successfully." -ForegroundColor Green
    Write-Host "Deletion is running in the background. Check status with:" -ForegroundColor Yellow
    Write-Host "  az group show --name $networkingRgName --subscription $azSubscriptionId" -ForegroundColor White
} else {
    Write-Host "`nFailed to delete resource group. Exit code: $LASTEXITCODE" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Cleanup Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nNote: Diagnostic settings are automatically deleted when resources are deleted." -ForegroundColor Green
Write-Host "Log Analytics Workspace (law-rai-prod-aue-platform-01) is NOT deleted." -ForegroundColor Green
Write-Host "It remains in the logging subscription for reuse." -ForegroundColor Green
