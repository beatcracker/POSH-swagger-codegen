[CmdletBinding(DefaultParameterSetName = 'Name')]
Param (
    [Parameter(ParameterSetName = 'Name')]
    [Parameter(Mandatory = $true, ParameterSetName = 'File')]
    [string]$ApiName = 'xkcd.com',

    [Parameter(Mandatory = $true, ParameterSetName = 'File')]
    [ValidateScript({
        Test-Path -Path $_ -PathType Leaf        
    })]
    [string]$InFile,

    [switch]$SkipInit
)

$FC = @{
    ForegroundColor = 'Magenta'
}

if (!$SkipInit) {
    Write-Host 'Installing Chocolatey' @FC
    & .\Install-Chocolatey.ps1

    Write-Host 'Installing JDK and Maven' @FC
    & .\Install-Prerequisites.ps1
    
    Write-Host 'Cloning Swagger-Codegen repo' @FC
    & .\Install-SwaggerCodegenRepository.ps1

    Write-Host 'Building Swagger-Codegen' @FC
    & .\Initialize-SwaggerCodegen.ps1
}

$SwaggerJar = '.\swagger-codegen\modules\swagger-codegen-cli\target\swagger-codegen-cli.jar'
$Guid = & .\New-DeterministicGuid.ps1 -ApiName $ApiName


$CSharp = @{
    ApiName = $ApiName
    OutDir = "$ApiName\CSharp"
    Language = 'csharp'
    Properties = "packageGuid={$Guid}"
    SwaggerJar = $SwaggerJar
}

$PowerShell = @{
    ApiName = $ApiName
    OutDir = "$ApiName\PowerShell"
    Language = 'powershell'
    Properties = 'packageGuid={0},csharpClientPath=$ScriptDir\..\CSharp' -f $Guid
    SwaggerJar = $SwaggerJar
}

Write-Host "Target API name: $ApiName" @FC

if ('File' -eq $PSCmdlet.ParameterSetName) {
    Write-Host "Target API file: $InFile" @FC

    $CSharp.InFile = $InFile
    $PowerShell.InFile = $InFile
}

Write-Host 'Generating C# client dependency' @FC
& .\New-SwaggerClient.ps1 @CSharp

Write-Host 'Generating PowerShell client' @FC
& .\New-SwaggerClient.ps1 @PowerShell

Write-Host 'Building C# assemblies and PowerShell client' @FC
& (Join-Path $PowerShell.OutDir 'Build.ps1')

Write-Host "Run this to import generated PowerShell module: " @FC -NoNewline
Write-Host "Import-Module -Name .\$ApiName\PowerShell\src\IO.Swagger -Verbose" -ForegroundColor DarkYellow