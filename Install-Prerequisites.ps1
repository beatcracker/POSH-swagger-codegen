Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"

choco install jdk8 maven git -y

Update-SessionEnvironment