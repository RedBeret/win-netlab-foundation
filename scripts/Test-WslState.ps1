[CmdletBinding()]
param(
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "WinNetlab.Foundation.psm1") -Force

$state = Get-WslState
$checks = @(
    [pscustomobject]@{
        Name = "WSL present"
        Status = if ($state.WslPresent) { "pass" } else { "fail" }
        Detail = $state.Detail
    },
    [pscustomobject]@{
        Name = "Ubuntu distro available"
        Status = if ($state.UbuntuDistro) { "pass" } else { "fail" }
        Detail = if ($state.UbuntuDistro) { $state.UbuntuDistro } else { "Ubuntu not found." }
    },
    [pscustomobject]@{
        Name = "Python 3 in WSL"
        Status = if ($state.PythonVersion -match "^Python 3") { "pass" } else { "fail" }
        Detail = if ($state.PythonVersion) { $state.PythonVersion } else { "python3 missing from Ubuntu." }
    }
)

$checks | Format-Table -AutoSize

if ($AsJson) {
    $state | ConvertTo-Json -Depth 6
}

if ($state.WslPresent -and $state.UbuntuDistro -and $state.PythonVersion -match "^Python 3") {
    exit 0
}

exit 1

