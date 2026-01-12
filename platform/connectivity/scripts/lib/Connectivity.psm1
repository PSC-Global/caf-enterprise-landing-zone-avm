#Requires -Version 7.0
<#
.SYNOPSIS
    Connectivity deployment module - Root module that aggregates all sub-modules

.DESCRIPTION
    This is an aggregate module that imports all connectivity deployment sub-modules.
    It contains no logic or functions - only module imports.
#>

$modulePath = $PSScriptRoot

Import-Module (Join-Path $modulePath "Connectivity.Common.psm1") -Force
Import-Module (Join-Path $modulePath "Connectivity.Azure.psm1") -Force
Import-Module (Join-Path $modulePath "Connectivity.Diagnostics.psm1") -Force
Import-Module (Join-Path $modulePath "Connectivity.Ipam.psm1") -Force
Import-Module (Join-Path $modulePath "Connectivity.Stages.psm1") -Force
