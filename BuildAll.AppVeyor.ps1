[CmdletBinding()]
Param (
    [string]$OutDir = '.\BuildResults'
)

filter Rename-InvalidFileNameChars {
    Param (
        [char]$Replacement = '-'
    )

    foreach ($char in [char[]]([System.IO.Path]::GetInvalidFileNameChars() + ':' )) {
        $_ = $_.Replace($char, $Replacement)
    }

    $_
}

function Invoke-PesterInJob {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            Test-Path -Path $_ -PathType Leaf
        })]
        [string]$TestPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResultPath
    )

    $PesterJob = Start-Job {
        Param (
            $TestPath,
            $ResultPath
        )

        Import-Module Pester -Force -ErrorAction Stop #| Out-Null
        Invoke-Pester -Path $TestPath -OutputFormat NUnitXml -OutputFile $ResultPath -PassThru

    } -ArgumentList $TestPath, $ResultPath

    $PesterJob | Wait-Job | Out-Null

    #not using Receive-Job to ignore any output to Host
    #TODO: how should this handle errors?
    #$job.Error | foreach { throw $_.Exception  }
    $PesterJob.Output
    $PesterJob.ChildJobs| ForEach-Object {
        $ChildJob = $_
        #$childJob.Error | foreach { throw $_.Exception }
        $ChildJob.Output
    }
    $PesterJob | Remove-Job
}





function Throttle-Jobs {
    [CmdletBinding()]
    Param (
        [int] $MaxJobs = 25,
        [TimeSpan]$SleepInterval = [TimeSpan]::FromSeconds(1)  
      
    )
      
    while ( (Get-Job -State Running | Measure-Object).Count -gt $MaxJobs ) {  
        Start-Sleep -Milliseconds $SleepInterval.TotalMilliseconds  
    }  
}  

$FC = @{
    ForegroundColor = 'Magenta'
}

Write-Host 'Cloning Swagger-Codegen repo' @FC
& .\Install-SwaggerCodegenRepository.ps1 *> $null

Write-Host 'Building Swagger-Codegen' @FC
& .\Initialize-SwaggerCodegen.ps1 *> $null


if ($ApiList = Invoke-WebRequest -UseBasicParsing -Uri https://api.apis.guru/v2/list.json | ConvertFrom-Json) {
    foreach ($ApiName in $ApiList.PSObject.Properties.Name) {
        foreach ($Version in $ApiList.$ApiName.versions.PSObject.Properties.Name) {
            $FsApiName, $FsVersion = $ApiName, $Version | Rename-InvalidFileNameChars
            $ModuleDir = "$FsApiName-$FsVersion"
            $CurrOutDir = Join-Path $OutDir $ModuleDir

            Throttle-Jobs -MaxJobs 4 -SleepInterval ([timespan]::FromSeconds(25))
            Start-Job -Name $ModuleDir -ScriptBlock {
                Param (
                    $CurrOutDir,
                    $ApiName,
                    $Version,
                    $ModuleDir
                )

                function Invoke-PesterInAppVeyor {
                    [CmdletBinding()]
                    Param (
                        [Parameter(Mandatory = $true)]
                        [string]$Name,

                        [Parameter(Mandatory = $true)]
                        [string]$TestPath
                    )

                    Add-AppveyorTest -Name $Name -Outcome Running
                    $TestResults = Join-Path (Split-Path $TestPath) "$Name.xml"
                    $ret = Invoke-Pester -Path $TestPath -OutputFormat NUnitXml -OutputFile $TestResults -PassThru
                    Add-TestResultToAppveyor -TestFile $TestResults
                    if ($ret.FailedCount -gt 0) {
                        Add-AppveyorMessage -Message "${Name}: $($ret.FailedCount) tests failed." -Category Error
                        Update-AppveyorTest -Name 'Pester' -Outcome Failed -ErrorMessage "$($ret.FailedCount) tests failed."
                    } else {
                        Update-AppveyorTest -Name $Name -Outcome Passed
                    }
                }


                function Add-TestResultToAppveyor {
                    <#
                    .SYNOPSIS
                        Upload test results to AppVeyor

                    .DESCRIPTION
                        Upload test results to AppVeyor

                    .EXAMPLE
                        Add-TestResultToAppVeyor -TestFile C:\testresults.xml

                    .LINK
                        https://github.com/RamblingCookieMonster/BuildHelpers

                    .LINK
                        about_BuildHelpers
                    #>
                    [CmdletBinding()]
                    [OutputType([void])]
                    Param (
                        # Appveyor Job ID
                        [String]
                        $APPVEYOR_JOB_ID = $Env:APPVEYOR_JOB_ID,

                        [ValidateSet('mstest','xunit','nunit','nunit3','junit')]
                        $ResultType = 'nunit',

                        # List of files to be uploaded
                        [Parameter(Mandatory,
                                   Position,
                                   ValueFromPipeline,
                                   ValueFromPipelineByPropertyName,
                                   ValueFromRemainingArguments
                        )]
                        [Alias("FullName")]
                        [string[]]
                        $TestFile
                    )

                    begin {
                        $wc = New-Object 'System.Net.WebClient'
                    }

                    process {
                        foreach ($File in $TestFile) {
                            if (Test-Path $File) {
                                Write-Verbose "Uploading $File for Job ID: $APPVEYOR_JOB_ID"
                                $wc.UploadFile("https://ci.appveyor.com/api/testresults/$ResultType/$($APPVEYOR_JOB_ID)", $File)
                            }
                        }
                    }

                    end {
                        $wc.Dispose()
                    }
                }


                if ($CurrModuleDir = & .\Build.ps1 -OutDir $CurrOutDir -ApiName $ApiName -Version $Version -SkipInit -PassThru) {
                    Invoke-PesterInAppVeyor -Name $ModuleDir -TestPath (
                        ("$CurrModuleDir\src\IO.Swagger.Tests.ps1" | Resolve-Path).ProviderPath
                    )
            
                    Compress-Archive -Path $CurrOutDir -DestinationPath "$CurrOutDir\$ModuleDir.zip"
                    Push-AppveyorArtifact "$CurrOutDir\$ModuleDir.zip"
                } else {
                    Write-Error "Failed to build module: $ModuleDir"
                }
            } -ArgumentList $CurrOutDir, $ApiName, $Version, $ModuleDir 
        }
    }
}

Receive-Job -Job (Get-Job) -Wait -AutoRemoveJob