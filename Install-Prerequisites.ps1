#Requires -RunAsAdministrator

<#
.Synopsis
    Install Java Development Kit and Maven
#>

[CmdletBinding()]
Param (
    [ValidateNotNullOrEmpty()]
    $Prerequisites = @('JDK','Maven')
)

Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

& 'choco.exe' @(('-y', 'install') + $Prerequisites)

Update-SessionEnvironment
