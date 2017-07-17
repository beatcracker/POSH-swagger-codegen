<#
.Synopsis
    Install dependencies, build Swagger Codegen and generate new API client.

.Parameter ApiName
    Name of API client to generate.
    
    * If used without InFile parameter, script will fetch API spec from https://apis.guru/openapi-directory/

    * If InFile parameter is used to specify custom Swagger spec file, ApiName is used as target directory name and for guid generation.

.Parameter Version
    If API has several versions in APIs.guru directory, you can specify which one to build.
    If not specified, 'preferred' version will be used, if exists.
    If no preferred version exists for API, most recent one will be used.

.Parameter InFile
    Custom Swagger spec file to generate API client from.

.Parameter OutDir
    Output directory for generated module.

.Parameter SkipInit
    Do not install prerequisites / build Swagger Codegen.

.Parameter PassThru
    Output path to generated module

.Parameter FixCSharpBuild
    Use workaround for C# client build issue:
    
    https://github.com/swagger-api/swagger-codegen/issues/6022

.Example
    Build.ps1

    Run as administrator to install all prerequisites, build Swagger Codegen and generate XKCD module.

.Example
    .\Build.ps1 -ApiName instagram.com -SkipInit

    If you already run Build.ps1 script as administrator and have all prerequisites, you can build instagram.com module by API name.

#>
[CmdletBinding(DefaultParameterSetName = 'Name')]
Param (
    [Parameter(ParameterSetName = 'Name')]
    [Parameter(Mandatory = $true, ParameterSetName = 'File')]
    [string]$ApiName = 'xkcd.com',

    [Parameter(ParameterSetName = 'Name')]
    [string]$Version,

    [Parameter(Mandatory = $true, ParameterSetName = 'File')]
    [ValidateScript({
        Test-Path -Path $_ -PathType Leaf        
    })]
    [string]$InFile,

    [string]$OutDir = $PSScriptRoot,

    [switch]$SkipInit,

    [switch]$PassThru,

    [switch]$FixCSharpBuild
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

$SwaggerJar = ('.\swagger-codegen\modules\swagger-codegen-cli\target\swagger-codegen-cli.jar' | Resolve-Path).ProviderPath
$OutDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
$Guid = & .\New-DeterministicGuid.ps1 -ApiName $ApiName
# Cludge
$FsApiName = $ApiName -replace ':', '-'

if (!(Test-Path -Path $SwaggerJar -PathType Leaf)) {
    throw "Can't find Swagger Codegen at path: $SwaggerJar"
}

$CSharp = @{
    ApiName = $ApiName
    Version = $Version
    OutDir = Join-Path $OutDir "$FsApiName\CSharp"
    Language = 'csharp'
    Properties = "packageGuid={$Guid}"
    SwaggerJar = $SwaggerJar
    PassThru = $PassThru
}

$PowerShell = @{
    ApiName = $ApiName
    Version = $Version
    OutDir = Join-Path $OutDir "$FsApiName\PowerShell"
    Language = 'powershell'
    Properties = 'packageGuid={0},csharpClientPath=$ScriptDir\..\CSharp' -f $Guid
    SwaggerJar = $SwaggerJar
    PassThru = $PassThru
}

Write-Host "Target API name: $ApiName" @FC
Write-Host "Target API version: $(($Version, 'not set')[!$Version])" @FC

if ('File' -eq $PSCmdlet.ParameterSetName) {
    Write-Host "Target API file: $InFile" @FC

    $CSharp.InFile = $InFile
    $PowerShell.InFile = $InFile
}

Write-Host 'Generating C# client dependency' @FC
$CSharpClientPath = & .\New-SwaggerClient.ps1 @CSharp

Write-Host 'Generating PowerShell client' @FC
$PoshClientPath = & .\New-SwaggerClient.ps1 @PowerShell

if ($PassThru) {
    $PoshClientPath
}

if ($FixCSharpBuild) {
    $NuGetPath = '.\Nuget'
    $NuGetExe = 'nuget.exe'

    if (! (Test-Path -Path "$NuGetPath\$NuGetExe")) {
        Write-Host "Downloading lastest NuGet binary to $NuGetPath\$NuGetExe" -ForegroundColor DarkGray

        New-Item -Path $NuGetPath -ItemType Directory  -ErrorAction SilentlyContinue > $null
        Invoke-WebRequest -UseBasicParsing -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile "$NuGetPath\$NuGetExe"
    }
    
    Write-Host "Copying NuGet binary to: $BuildBatPath\$NuGetExe" -ForegroundColor DarkGray
    Copy-Item -Path "$NuGetPath\$NuGetExe" -Destination "$BuildBatPath\$NuGetExe" -Force
}

Write-Host 'Building C# assemblies and PowerShell client' @FC
& (Join-Path $PowerShell.OutDir 'Build.ps1')

Write-Host 'Generating tests' @FC
& .\New-SwaggerClientTests.ps1 @PowerShell

Write-Host "Run this to import generated PowerShell module: " @FC -NoNewline
Write-Host "Import-Module -Name $(Join-Path $OutDir "$FsApiName\PowerShell\src\IO.Swagger") -Verbose" -ForegroundColor DarkYellow