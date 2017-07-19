#Requires -RunAsAdministrator

<#
.Synopsis
    Install Chocolatey
#>

Invoke-Expression (
    (New-Object -TypeName System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')
)