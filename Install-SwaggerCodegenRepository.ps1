<#
.Synopsis
    Clone Swagger Codegen repository
#>

[CmdletBinding()]
Param (
    $SwaggerPath = '.\swagger-codegen'
)

$Clone = @(
    'clone',
    '--quiet',
    '--depth',
    '1',
    'https://github.com/swagger-api/swagger-codegen.git'
    $SwaggerPath
)

$Pull = @(
    'pull',
    '--quiet'
)

if (Test-Path -Path $SwaggerPath) {
    & 'git.exe' $Pull
} else {
    & 'git.exe' $Clone
}