﻿[CmdletBinding()]
Param (
    [string]$OutDir = '.\BuildResults'
)

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

    $PesterPath = Get-Module Pester | Select-Object -First 1 -ExpandProperty Path

    $PesterJob = Start-Job {
        Param (
            $PesterPath,
            $TestPath,
            $ResultPath
        )

        Import-Module $PesterPath -Force -ErrorAction Stop | Out-Null
        Invoke-Pester -Path $TestPath -OutputFormat NUnitXml -OutputFile $ResultPath -PassThru

    } -ArgumentList $PesterPath, $TestPath, $ResultPath

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


function Invoke-PesterInAppVeyor {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$TestPath
    )

    Add-AppveyorTest -Name $Name -Outcome Running
    $TestResults = Join-Path $TestPath "$Name.xml"
    $ret = Invoke-PesterInJob -TestPath $TestPath -ResultPath $TestResults
    Add-TestResultToAppveyor -TestFile $TestResults
    if ($ret.FailedCount -gt 0) {
        Add-AppveyorMessage -Message "${Name}: $($ret.FailedCount) tests failed." -Category Error
        Update-AppveyorTest -Name 'Pester' -Outcome Failed -ErrorMessage "$($ret.FailedCount) tests failed."
    } else {
        Update-AppveyorTest -Name $Name -Outcome Passed
    }
}

# First module build installs and builds prerequisites
$SkipInit = $false

if ($ApiList = Invoke-WebRequest -UseBasicParsing -Uri https://api.apis.guru/v2/list.json | ConvertFrom-Json) {
    foreach ($ApiName in $ApiList.PSObject.Properties.Name) {
        foreach ($Version in $ApiList.$ApiName.versions.PSObject.Properties.Name) {
            $CurrOutDir = Join-Path $OutDir "$ApiName-$Version" 

            & .\Build.ps1 -OutDir $CurrOutDir -ApiName $ApiName -Version $Version -SkipInit:$SkipInit

            Invoke-PesterInAppVeyor -Name "$ApiName-$Version" -TestPath "$CurrOutDir\$ApiName\PowerShell\src\IO.Swagger.Tests.ps1"
            
            # Skip prerequisites on subsequent builds
            $SkipInit = $true
        }
    }
}