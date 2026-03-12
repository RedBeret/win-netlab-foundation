[CmdletBinding()]
param(
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "WinNetlab.Foundation.psm1") -Force

$state = Get-DockerState
$checks = @(
    [pscustomobject]@{
        Name = "docker on PATH"
        Status = if ($state.DockerPresent) { "pass" } else { "fail" }
        Detail = if ($state.DockerPresent) { $state.DockerCommandPath } else { $state.Detail }
    },
    [pscustomobject]@{
        Name = "Docker Desktop running"
        Status = if ($state.DockerRunning) { "pass" } else { "fail" }
        Detail = if ($state.DockerRunning) { $state.Detail } else { "Start Docker Desktop first." }
    },
    [pscustomobject]@{
        Name = "docker compose available"
        Status = if ($state.ComposeAvailable) { "pass" } else { "fail" }
        Detail = if ($state.ComposeAvailable) { "Context: $($state.Context)" } else { "Update Docker Desktop." }
    }
)

$checks | Format-Table -AutoSize

if ($AsJson) {
    $state | ConvertTo-Json -Depth 6
}

if ($state.DockerPresent -and $state.DockerRunning -and $state.ComposeAvailable) {
    exit 0
}

exit 1

