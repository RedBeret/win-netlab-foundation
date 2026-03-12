[CmdletBinding()]
param(
    [string]$HealthReportPath = (Join-Path $PSScriptRoot "..\artifacts\host-health.json"),
    [string]$SummaryReportPath = (Join-Path $PSScriptRoot "..\artifacts\lab-summary.json"),
    [switch]$KeepServiceUp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "WinNetlab.Foundation.psm1") -Force

$rootPath = Get-RepositoryRoot
$logPath = Get-DefaultLogPath
$composeUp = $false

Write-StructuredLog -Action "demo.start" -Message "Starting the Windows-first synthetic demo." -LogPath $logPath

Initialize-LabScaffold | Out-Null

$report = Get-HostPrereqReport
$writtenPath = Write-HealthReport -Report $report -OutputPath $HealthReportPath
Write-CheckTable -Checks $report.checks
Write-Host ("Overall status: {0}" -f $report.overall_status)
Write-Host ("Health report: {0}" -f $writtenPath)

if ($report.overall_status -eq "fail") {
    Write-StructuredLog -Level "ERROR" -Action "demo.prereqs" -Message "Demo stopped because a required prerequisite failed." -LogPath $logPath
    throw "Prerequisite validation failed. See $writtenPath for details."
}

try {
    $dockerState = Get-DockerState
    if (-not $dockerState.DockerRunning -or -not $dockerState.ComposeAvailable) {
        throw "Docker Desktop and docker compose are required for the one-command demo."
    }

    $composeArgs = @("compose", "-f", (Join-Path $rootPath "compose.yaml"), "up", "-d", "--build", "synthetic-health")
    $composeResult = Invoke-Process -FilePath $dockerState.DockerCommandPath -Arguments $composeArgs -TimeoutSeconds 240 -WorkingDirectory $rootPath
    if ($composeResult.ExitCode -ne 0) {
        throw "docker compose up failed: $($composeResult.StdErr.Trim())"
    }

    $composeUp = $true
    Write-StructuredLog -Action "demo.compose" -Message "Synthetic health service started." -LogPath $logPath

    $probeResult = Invoke-WithRetry -OperationName "demo.healthcheck" -MaxAttempts 5 -InitialDelaySeconds 2 -ScriptBlock {
        Test-HttpHealthEndpoint -Uri "http://127.0.0.1:8088/health" -TimeoutSeconds 5
    } -SuccessScript {
        param($result)
        $result.Success
    }

    if (-not $probeResult.Success) {
        throw "The synthetic health endpoint did not become ready."
    }

    Write-StructuredLog -Action "demo.healthcheck" -Message "Synthetic health endpoint is ready." -LogPath $logPath -Details @{
        status_code = $probeResult.StatusCode
    }

    $summaryPathForWsl = if ([System.IO.Path]::IsPathRooted($SummaryReportPath)) {
        Convert-WindowsPathToWsl -WindowsPath $SummaryReportPath
    }
    else {
        $SummaryReportPath -replace "\\", "/"
    }
    $quotedSummaryPath = "'" + ($summaryPathForWsl -replace "'", "'""'""'") + "'"

    $demoCommand = @"
if command -v make >/dev/null 2>&1; then
  REPORT=$quotedSummaryPath DB=artifacts/lab-state.db CONFIG=configs/lab.config.json PROBE_URL=http://127.0.0.1:8088/health make demo
else
  PYTHONPATH=src python3 -m win_netlab_foundation.cli demo --config configs/lab.config.json --db artifacts/lab-state.db --report $quotedSummaryPath --probe-url http://127.0.0.1:8088/health
fi
"@

    $demoResult = Invoke-WslRepoCommand -Command $demoCommand -TimeoutSeconds 240
    if ($demoResult.ExitCode -ne 0) {
        throw "WSL demo command failed: $($demoResult.StdErr.Trim())"
    }

    Write-StructuredLog -Action "demo.wsl" -Message "WSL-side demo completed." -LogPath $logPath
    Write-Host "Demo summary: $SummaryReportPath"
    Write-Host "Rollback note: docker compose is torn down automatically unless -KeepServiceUp is used. Delete artifacts/lab-state.db and artifacts/lab-summary.json to reset the demo state."
}
finally {
    if ($composeUp -and -not $KeepServiceUp) {
        $dockerState = Get-DockerState
        if ($dockerState.DockerPresent) {
            [void](Invoke-Process -FilePath $dockerState.DockerCommandPath -Arguments @("compose", "-f", (Join-Path $rootPath "compose.yaml"), "down", "--remove-orphans") -TimeoutSeconds 120 -WorkingDirectory $rootPath)
            Write-StructuredLog -Action "demo.compose" -Message "Synthetic health service stopped." -LogPath $logPath
        }
    }
}
