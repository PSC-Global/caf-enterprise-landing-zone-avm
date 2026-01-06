#Requires -Version 7.0
<#
.SYNOPSIS
    Sets up RBAC for subscription vending automation
    
.DESCRIPTION
    Creates a custom "Subscription Vending Operator" role at tenant scope with least-privilege
    permissions for subscription alias creation and deployment. Optionally assigns the role to
    a service principal or user identity.
    
.PARAMETER AssigneeObjectId
    Object ID of the user or service principal to assign the role to
    
.PARAMETER AssigneeName
    Display name of the assignee (for logging purposes)
    
.PARAMETER SkipRoleCreation
    Skip role definition creation (if already exists)
    
.PARAMETER SkipAssignment
    Skip role assignment (only create the role definition)
    
.EXAMPLE
    # Create role and assign to current user
    ./setup-vending-rbac.ps1 -AssigneeObjectId "00000000-0000-0000-0000-000000000000" -AssigneeName "your-email@example.com"
    
.EXAMPLE
    # Create role and assign to service principal
    ./setup-vending-rbac.ps1 -AssigneeObjectId "12345678-1234-1234-1234-123456789abc" -AssigneeName "sp-subscription-vending"
    
.EXAMPLE
    # Only create role, don't assign
    ./setup-vending-rbac.ps1 -SkipAssignment
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AssigneeObjectId,
    
    [Parameter(Mandatory = $false)]
    [string]$AssigneeName,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipRoleCreation,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipAssignment
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# Helper Functions
# =============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# =============================================================================
# Validate Prerequisites
# =============================================================================

Write-Log "Validating prerequisites..."

# Check if user has permissions at tenant root
try {
    $currentUser = az account show --query user -o json | ConvertFrom-Json
    Write-Log "Current user: $($currentUser.name)" -Level "INFO"
    
    # Try to list tenant root role assignments to verify permissions
    az role assignment list --scope "/" --query "[0]" -o json 2>&1 | Out-Null
    Write-Log "Tenant root access confirmed" -Level "SUCCESS"
}
catch {
    Write-Log "You may not have sufficient permissions at tenant root. This script requires Global Administrator or User Access Administrator role." -Level "WARN"
}

# =============================================================================
# Create Custom Role Definition
# =============================================================================

if (!$SkipRoleCreation) {
    Write-Log "Creating custom role 'Subscription Vending Operator'..." -Level "SUCCESS"
    
    $roleDefPath = "../rbac/subscription-vending-role.json"
    
    if (!(Test-Path $roleDefPath)) {
        Write-Log "Role definition file not found: $roleDefPath" -Level "ERROR"
        exit 1
    }
    
    # Check if role already exists
    $existingRole = az role definition list --name "Subscription Vending Operator" --query "[0]" -o json 2>$null
    
    if ($existingRole -and $existingRole -ne "null" -and $existingRole.Length -gt 0) {
        Write-Log "Role 'Subscription Vending Operator' already exists. Updating..." -Level "WARN"
        az role definition update --role-definition $roleDefPath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to update role definition" -Level "ERROR"
            exit 1
        }
        Write-Log "Role definition updated successfully" -Level "SUCCESS"
    }
    else {
        Write-Log "Creating new role definition..." -Level "INFO"
        az role definition create --role-definition $roleDefPath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to create role definition" -Level "ERROR"
            Write-Log "If the role already exists, use -SkipRoleCreation flag" -Level "WARN"
            exit 1
        }
        Write-Log "Role definition created successfully" -Level "SUCCESS"
    }
}
else {
    Write-Log "Skipping role creation (SkipRoleCreation flag set)" -Level "WARN"
}

# =============================================================================
# Wait for Role Propagation
# =============================================================================

if (!$SkipRoleCreation -and !$SkipAssignment) {
    Write-Log "Waiting for role definition to propagate..." -Level "INFO"
    
    $maxAttempts = 30
    $attempt = 0
    $roleAvailable = $false
    
    while ($attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 2
        $roleCheck = az role definition list --name "Subscription Vending Operator" --query "[0].roleName" -o tsv 2>$null
        
        if ($roleCheck -eq "Subscription Vending Operator") {
            $roleAvailable = $true
            Write-Log "Role definition is now available" -Level "SUCCESS"
            break
        }
        
        $attempt++
    }
    
    if (!$roleAvailable) {
        Write-Log "Role definition did not propagate within expected time. Please wait a few minutes and run with -SkipRoleCreation flag." -Level "ERROR"
        exit 1
    }
}

# =============================================================================
# Assign Role to Identity
# =============================================================================

if (!$SkipAssignment) {
    if ([string]::IsNullOrWhiteSpace($AssigneeObjectId)) {
        Write-Log "AssigneeObjectId is required when not using -SkipAssignment" -Level "ERROR"
        Write-Log "Get your object ID: az ad user show --id your-email@domain.com --query id -o tsv" -Level "INFO"
        Write-Log "Or for SP: az ad sp show --id <app-id> --query id -o tsv" -Level "INFO"
        exit 1
    }
    
    Write-Log "Assigning role to $($AssigneeName ?? $AssigneeObjectId)..." -Level "SUCCESS"
    
    # Check if assignment already exists at tenant root (required for subscription creation)
    $existingAssignment = az role assignment list `
        --role "Subscription Vending Operator" `
        --assignee $AssigneeObjectId `
        --scope "/" `
        --query "[0]" -o json 2>$null
    
    if ($existingAssignment -and $existingAssignment -ne "null" -and $existingAssignment.Length -gt 0) {
        Write-Log "Role assignment already exists for this identity" -Level "WARN"
    }
    else {
        az role assignment create `
            --role "Subscription Vending Operator" `
            --assignee $AssigneeObjectId `
            --scope "/" `
            --output none
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to assign role" -Level "ERROR"
            exit 1
        }
        
        Write-Log "Role assigned successfully" -Level "SUCCESS"
    }
}
else {
    Write-Log "Skipping role assignment (SkipAssignment flag set)" -Level "WARN"
}

# =============================================================================
# Verify Setup
# =============================================================================

Write-Log "Verifying setup..." -Level "INFO"

# Verify role exists
$role = az role definition list --name "Subscription Vending Operator" --query "[0]" -o json | ConvertFrom-Json

if ($role) {
    Write-Log "Role 'Subscription Vending Operator' is available" -Level "SUCCESS"
    Write-Log "Role ID: $($role.id)" -Level "INFO"
}
else {
    Write-Log "Role verification failed" -Level "ERROR"
    exit 1
}

# Verify assignment (if applicable)
if (!$SkipAssignment -and ![string]::IsNullOrWhiteSpace($AssigneeObjectId)) {
    $assignment = az role assignment list `
        --role "Subscription Vending Operator" `
        --assignee $AssigneeObjectId `
        --scope "/" `
        --query "[0]" -o json | ConvertFrom-Json
    
    if ($assignment) {
        Write-Log "Role assignment verified for $($AssigneeName ?? $AssigneeObjectId)" -Level "SUCCESS"
        Write-Log "Assignment ID: $($assignment.id)" -Level "INFO"
    }
    else {
        Write-Log "Role assignment verification failed" -Level "ERROR"
        exit 1
    }
}

# =============================================================================
# Summary
# =============================================================================

Write-Log ""
Write-Log "Subscription vending RBAC setup completed successfully!" -Level "SUCCESS"
Write-Log ""
Write-Log "Next steps:"
Write-Log "1. If using a service principal, also grant 'Subscription Creator' role on your MCA billing invoice section:"
Write-Log "   az role assignment create --role 'Subscription Creator' --assignee <sp-object-id> --scope '<billing-invoice-section-id>'"
Write-Log ""
Write-Log "2. Test subscription vending with WhatIf mode:"
Write-Log "   cd subscription-vending/scripts"
Write-Log "   pwsh ./deploy-mg-alias.ps1 -SubscriptionId 'platform-mgmt-01' -WhatIf"
Write-Log ""
Write-Log "3. Deploy your first subscription:"
Write-Log "   pwsh ./deploy-mg-alias.ps1 -SubscriptionId 'platform-mgmt-01'"
Write-Log ""
