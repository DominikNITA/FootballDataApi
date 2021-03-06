# All file took (with modifications from http://andrewlock.net/publishing-your-first-nuget-package-with-appveyor-and-myget/)

<#
.SYNOPSIS
    This method will test if psbuild is installed by checking that
    the command Invoke-MSBuild is available.
    If it doesn't exist, it will call Install-Module psbuild to install it
#>
function Assert-PsBuildInstalled {
    [cmdletbinding()]
    param(
        [string]$psbuildInstallUri = 'https://raw.githubusercontent.com/ligershark/psbuild/master/src/GetPSBuild.ps1'
    )
    process{
        if(-not (Get-Command "Invoke-MsBuild" -errorAction SilentlyContinue)){
            'Installing psbuild from [{0}]' -f $psbuildInstallUri | Write-Verbose
            (new-object Net.WebClient).DownloadString($psbuildInstallUri) | iex
        }
        else{
            'psbuild already loaded, skipping download' | Write-Verbose
        }

        # make sure it's loaded and throw if not
        if(-not (Get-Command "Invoke-MsBuild" -errorAction SilentlyContinue)){
            throw ('Unable to install/load psbuild from [{0}]' -f $psbuildInstallUri)
        }
    }
}

# Taken from psake https://github.com/psake/psake

<#  
.SYNOPSIS
  This is a helper function that runs a scriptblock and checks the PS variable $lastexitcode
  to see if an error occcured. If an error is detected then an exception is thrown.
  This function allows you to run command-line programs without having to
  explicitly check the $lastexitcode variable.
.EXAMPLE
  exec { svn info $repository_trunk } "Error executing SVN. Please verify SVN command-line client is installed"
#>
function Exec {
    [CmdletBinding()]
    param(
        [Parameter(Position=0,Mandatory=1)][scriptblock]$cmd,
        [Parameter(Position=1,Mandatory=0)][string]$errorMessage = ($msgs.error_bad_command -f $cmd)
    )
    & $cmd
    if ($lastexitcode -ne 0) {
        throw ("Exec: " + $errorMessage)
    }
}

if (Test-Path .\artifacts) {
    Remove-Item .\artifacts -Force -Recurse
}

Assert-PsBuildInstalled

'Starting dotnet restore' | Write-Verbose
exec {& dotnet restore .\src\FootballDataApi}
exec {& dotnet restore .\tests\FootballDataApi.Tests}

'Starting dotnet build' | Write-Verbose
exec {& dotnet build .\src\FootballDataApi\FootballDataApi.csproj }

$revision = @{ $true = $env:APPVEYOR_BUILD_NUMBER; $false = 1 }[$env:APPVEYOR_BUILD_NUMBER -ne $NULL];
$revision = "build{0:D4}" -f [convert]::ToInt32($revision, 10)

'Running tests' | Write-Verbose
exec { & dotnet test .\tests\FootballDataApi.Tests\FootballDataApi.Tests.csproj -c Release }

'Creating NuGet packages' | Write-Verbose
exec { & dotnet pack .\src\FootballDataApi -c Release -o .\artifacts --version-suffix=$revision }