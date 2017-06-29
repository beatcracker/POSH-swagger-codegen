[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true)]
    [string]$ApiName,

    [Parameter(Mandatory = $true)]
    [ValidateScript({
        Test-Path -Path $_ -PathType Container
    })]
    [string]$OutDir,

    # Dummy param to allow Mandatory for OutDir.
    # Otherwise, splatting will fail.
    [Parameter(ValueFromRemainingArguments = $true)]
    $Splat
)

$BasePath = 'src'
$SwaggerPath = 'IO.Swagger'

$TestTpl = '
    $here = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    Describe "Module: {1}" {{
        Context "Basic tests" {{
            It "Should have manifest" {{
                Test-Path -Path "$here\{0}\{0}.psd1" | Should Be $true
            }}

            # Requires PS 5.1
            It "Shoud have correct manifest" {{
                try {{
                    Test-ModuleManifest -Path "$here\{0}\{0}.psd1" -ErrorAction Stop
                }} finally {{}}
            }}

            It "Should import" {{
                try {{
                    Import-Module -Name "$here\{0}" -Force -ErrorAction Stop
                }} finally {{
                    Remove-Module -Name "$here\{0}" -Force -ErrorAction SilentlyContinue
                }}
            }}
        }}
    }}
'

$TestTpl -f $SwaggerPath, $ApiName | Out-File -FilePath (
    Join-Path "$OutDir\$BasePath" "$SwaggerPath.Tests.ps1"
) -Encoding utf8 -Force -Confirm:$false