<#
    .SYNOPSIS
        Root module file.

    .DESCRIPTION
        The root module file loads all classes, helpers and functions into the
        module context.
#>

# Get and dot source all helper functions (internal)
Split-Path -Path $PSCommandPath |
    Get-ChildItem -Filter 'Helpers' -Directory |
        Get-ChildItem -Include '*.ps1' -File -Recurse |
            ForEach-Object { . $_.FullName }

# Get and dot source all external functions (public)
Split-Path -Path $PSCommandPath |
    Get-ChildItem -Filter 'Functions' -Directory |
        Get-ChildItem -Include '*.ps1' -File -Recurse |
            ForEach-Object { . $_.FullName }

# Module behavior
Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Set module version
$Script:PSModuleVersion = Import-PowerShellDataFile -Path $PSCommandPath.Replace('.psm1', '.psd1') | Select-Object -ExpandProperty 'ModuleVersion'
