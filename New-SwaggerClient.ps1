<#
.Synopsis
    Generate new API client with Swagger Codegen.

.Description
    Generate new API client with Swagger Codegen.
    Requires Java Development Kit and Maven installed.

.Parameter ApiName
    Name of API client to generate.
    
    * If used without InFile parameter, script will fetch API spec from https://apis.guru/openapi-directory/

    * If InFile parameter is used to specify custom Swagger spec file, ApiName is used as target directory name and for guid generation.

.Parameter InFile
    Custom Swagger spec file to generate API client from.

.Parameter Language
    API client language (csharp/powershell/etc)

.Parameter OutDir
    Directory, where generated API client will be created

.Parameter Properties
    Additional properties to pass to swagger-codegen-cli

.Parameter SwaggerJar
    Path to swagger-codegen-cli.jar
#>
[CmdletBinding(DefaultParameterSetName = 'Name')]
Param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
    [Parameter(Mandatory = $true, ParameterSetName = 'File')]
    [string]$ApiName,

    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'File')]
    [ValidateScript({
        Test-Path -Path $_ -PathType Leaf        
    })]
    [string]$InFile,

    [Parameter(Mandatory = $true)]
    [string]$Language,

    [Parameter(Mandatory = $true)]
    [string]$OutDir,

    [string]$Properties,

    [Parameter(Mandatory = $true)]
    [ValidateScript({
        Test-Path -Path $_ -PathType Leaf        
    })]
    [string]$SwaggerJar
)

End {
    $RemoveInFile = $false

    if ('Name' -eq $PSCmdlet.ParameterSetName) {
        $RemoveInFile = $true
        $ApiList = Invoke-WebRequest -UseBasicParsing -Uri https://api.apis.guru/v2/list.json | ConvertFrom-Json
        if ($ApiList.$ApiName) {
            $ApiUrl = if ($PreferredVersion = $ApiList.$ApiName.preferred) {
                $ApiList.$ApiName.versions.$PreferredVersion.swaggerYamlUrl
            } else {
                $ApiList.$ApiName.versions.PSObject.Properties.Name | ForEach-Object {
                    $ApiList.$ApiName.versions.$_
                } | Sort-Object -Property added -Descending | Select-Object -First 1 -ExpandProperty swaggerYamlUrl
            }

            $InFile = [System.IO.Path]::GetTempFileName()
            Invoke-WebRequest -UseBasicParsing -Uri $ApiUrl -OutFile $InFile

        } else {
            throw "API not found: $ApiName"
        }
    }

    $Arguments =  @(
        '-jar',
        ($SwaggerJar | Resolve-Path).ProviderPath
        'generate'
        '-i'
        ($InFile | Resolve-Path).ProviderPath
        '-l'
        $Language
        '-o'
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
    )

    if ($Properties) {
        $Arguments += @(
            '--additional-properties',
            $Properties
        )
    }

    $ret = & java.exe $Arguments 2>&1

    if ($LASTEXITCODE) {
        $ret | Out-String | Write-Error
    }

    if ($RemoveInFile) {
        Remove-Item -LiteralPath $InFile
    }
}