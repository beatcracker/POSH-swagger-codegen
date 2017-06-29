<#
.Synopsis
    Clone Swagger Codegen repository
#>

& 'git.exe' @(
    'clone',
    '--depth',
    '1',
    'https://github.com/swagger-api/swagger-codegen.git'
)