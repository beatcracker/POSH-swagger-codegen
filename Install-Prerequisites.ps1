#Requires -RunAsAdministrator

<#
.Synopsis
    Install Java Development Kit and Maven
#>

Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

choco install jdk8 maven -y

Update-SessionEnvironment
