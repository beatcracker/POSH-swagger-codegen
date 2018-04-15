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

.Parameter Version
    If API has several versions in APIs.guru directory, you can specify which one to build.
    If not specified, 'preferred' version will be used, if exists.
    If no preferred version exists for API, most recent one will be used.

.Parameter InFile
    Custom Swagger spec file to generate API client from.

.Parameter Language
    API client language (csharp/powershell/etc)

.Parameter OutDir
    Directory, where generated API client will be created

.Parameter Properties
    Additional properties to pass to swagger-codegen-cli

.Parameter SwaggerJarPath
    Path to swagger-codegen-cli.jar

.Parameter PassThru
    Output path to generated module
#>
[CmdletBinding(DefaultParameterSetName = 'Name')]
Param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Name')]
    [Parameter(Mandatory = $true, ParameterSetName = 'File')]
    [string]$ApiName,

    [Parameter(ParameterSetName = 'Name')]
    [string]$Version,

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
    [string]$SwaggerJarPath,

    [switch]$PassThru
)

Begin {
    Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop

    <#
    .Synopsis
        Convert JSON strin to object using JavaScriptSerializer.
        Can handle case-sensitive JSON.

    .Parameter MaxJsonLength
        The maximum length of JSON strings. The default is [int]::MaxValue.

    .Parameter RecursionLimit
        The number of object levels. The default is 100.
    #>
    function ConvertFrom-JsonViaJSSerializer {
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [AllowEmptyString()]
            [string]$InputObject,

            [int]$MaxJsonLength = [int]::MaxValue,

            [int]$RecursionLimit
        )

        Begin {
            $JSSerializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer

            if ($MaxJsonLength) {
                $JSSerializer.MaxJsonLength = $MaxJsonLength
            }

            if ($RecursionLimit) {
                $JSSerializer.RecursionLimit = $RecursionLimit
            }
        }


        Process {
            $JSSerializer.DeserializeObject($InputObject)
        }
    }
}

End {
    $RemoveInFile = $false

    if ('Name' -eq $PSCmdlet.ParameterSetName) {
        $ApiList = Invoke-WebRequest -UseBasicParsing -Uri https://api.apis.guru/v2/list.json | ConvertFrom-JsonViaJSSerializer
        if ($ApiList.$ApiName) {
            $ApiUrl = if ($Version) {
                $ApiList.$ApiName.versions.$Version.swaggerYamlUrl
            } elseif ($PreferredVersion = $ApiList.$ApiName.preferred) {
                $ApiList.$ApiName.versions.$PreferredVersion.swaggerYamlUrl
            } else {
                $ApiList.$ApiName.versions.PSObject.Properties.Name | ForEach-Object {
                    $ApiList.$ApiName.versions.$_
                } | Sort-Object -Property added -Descending | Select-Object -First 1 -ExpandProperty swaggerYamlUrl
            }

            if ($ApiUrl) {
                $InFile = [System.IO.Path]::GetTempFileName()
                $RemoveInFile = $true

                Invoke-WebRequest -UseBasicParsing -Uri $ApiUrl -OutFile $InFile -ErrorAction Stop
            } else {
                throw "Can't find API version '$Version' for '$ApiName'"
            }

        } else {
            throw "API not found: $ApiName"
        }
    }

    $OutDirAbsolute = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutDir)
    $Arguments =  @(
        '-jar',
        ($SwaggerJarPath | Resolve-Path).ProviderPath
        'generate'
        '-i'
        ($InFile | Resolve-Path).ProviderPath
        '-l'
        $Language
        '-o'
        $OutDirAbsolute
    )

    if ($Properties) {
        $Arguments += @(
            '--additional-properties',
            $Properties
        )
    }

    Write-Host "Commandline: java.exe $Arguments" -ForegroundColor Green
    $ret = & java.exe $Arguments 2>&1

    if ($LASTEXITCODE) {
        $ret | Out-String | Write-Error
    } else {
        if ($PassThru) {
            $OutDirAbsolute
        }
    }

    if ($RemoveInFile) {
        Remove-Item -LiteralPath $InFile
    }
}