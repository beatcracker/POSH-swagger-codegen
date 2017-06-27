#Requires -RunAsAdministrator
Invoke-Expression (
    (New-Object -Typename System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')
)