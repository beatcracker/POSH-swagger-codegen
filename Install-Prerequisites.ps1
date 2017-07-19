#Requires -RunAsAdministrator

<#
.Synopsis
    Install Java Development Kit and Maven
#>

[CmdletBinding()]
Param (
    $Prerequisites = @('JDK','Maven')
)

if ($Prerequisites) {
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

    & 'choco.exe' @(('-y', 'install') + $Prerequisites)

    Update-SessionEnvironment
}