#Requires -RunAsAdministrator

<#
.Synopsis
    Install Java Development Kit and Maven
#>

[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    $Prerequisites = @('JDK8','Maven')
)

Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

& 'choco.exe' @(
    'install'
    $Prerequisites
    '--confirm'
)

Update-SessionEnvironment