<#
.Synopsis
    Build Swagger Codegen
#>

[CmdletBinding()]
Param (
    $SwaggerPath = '.\swagger-codegen'
)

Push-Location $SwaggerPath

& 'mvn.exe' @('clean', 'package')

Pop-Location