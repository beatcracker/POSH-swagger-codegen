<#
.Synopsis
    Build Swagger Codegen
#>

Push-Location .\swagger-codegen

mvn clean package

Pop-Location