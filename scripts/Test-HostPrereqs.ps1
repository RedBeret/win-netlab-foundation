[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\artifacts\host-health.json"),
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "WinNetlab.Foundation.psm1") -Force

$report = Get-HostPrereqReport
$writtenPath = Write-HealthReport -Report $report -OutputPath $OutputPath

Write-CheckTable -Checks $report.checks
Write-Host ("Overall status: {0}" -f $report.overall_status)
Write-Host ("Health report: {0}" -f $writtenPath)

if ($AsJson) {
    $report | ConvertTo-Json -Depth 8
}

if ($report.overall_status -eq "fail") {
    exit 1
}

exit 0
